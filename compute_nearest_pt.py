import sys, getopt
import pandas as pd
import numpy as np
import os
from scipy.spatial import Voronoi, voronoi_plot_2d
from shapely.geometry import Point, Polygon
import json
import matplotlib.pyplot as plt
import requests
import osmnx as ox
import networkx as nx
import folium
from haversine import haversine_vector, Unit, haversine
import random

def get_walking_distance(coordinates, pt_stop, straight_distance):
    body = {"coordinates":[coordinates, pt_stop]}    
    headers = {
        'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
        'Content-Type': 'application/json; charset=utf-8'
    }
    call = requests.post('http://localhost:8080/ors/v2/directions/foot-walking', json=body, headers=headers)
    data = json.loads(call.text)
    try:
        return data['routes'][0]['summary']['distance']
    except:
        return straight_distance

def progress_bar(current, total, name, bar_length = 20):
    percent = float(current) * 100 / total
    arrow   = '-' * int(percent/100 * bar_length - 1) + '>'
    spaces  = ' ' * (bar_length - len(arrow))

    print(name+': [%s%s] %.1f %%' % (arrow, spaces, percent), end='\r')
    
try:
    opts, args = getopt.getopt(sys.argv[1:],"hd:t:",["district=","type="])
except getopt.GetoptError:
    print('compute_nearest_pt.py -d <district> -t <type>')
    sys.exit(2)
for opt, arg in opts:
    if opt == '-h':
        print('compute_nearest_pt.py -d <district> -t <type>')
        sys.exit()
    elif opt in ("-d", "--district"):
        district = int(arg)
    elif opt in ("-t", "--type"):
        req_stop_type = int(arg)
        
df_stops_gtf = pd.read_csv("gtfs/stops.txt")
stop_types = pd.read_csv("stop_types.txt", index_col=False)
df_stops_gtf = df_stops_gtf.loc[[x for x in range(len(df_stops_gtf)) if str(req_stop_type) in stop_types.loc[x, "stop_type"]], :]
stop_coordinates = df_stops_gtf[['stop_lon', 'stop_lat']].values.tolist()
stop_names = df_stops_gtf['stop_name'].values.tolist()
n_stops = len(stop_coordinates)

with open(f"ADRESSENOGD/ADRESSENOGD_1{district:02d}0.json", "r") as f:
    data_addresses = json.load(f)
    
distances_to_pt = []
straight_distances_to_pt = []
closest_pt = []
address_lon = []
address_lat = []
pt_lon = []
pt_lat = []

for i in range(data_addresses['totalFeatures']):
    progress_bar(i, data_addresses['totalFeatures'], f"Wien 1{district:02d}0 pt-{req_stop_type}", bar_length = 20)
    coordinates = data_addresses['features'][i]['geometry']['coordinates']
    address_coordinates = (coordinates[1], coordinates[0])
    
    # Compute Euclidean distance in meters
    straight_distances = []
    for pt in stop_coordinates:
        distance = haversine(coordinates, pt, unit=Unit.METERS)
        straight_distances.append(distance)
        
    straight_distances_sorted = sorted(straight_distances)
    sorted_index = np.argsort(straight_distances)
        
    stop_code = 1
    minimum_walking_distance = get_walking_distance(coordinates, stop_coordinates[sorted_index[0]], straight_distances[sorted_index[0]])
    closest_pt_index = sorted_index[0]
    stops_checked = [sorted_index[0]] # contains indices of straight distances! not straight_distances_sorted
    while 1:
        sorted_index_tocheck = sorted_index.copy()
        sorted_index_tocheck = [e for e in sorted_index_tocheck if e not in stops_checked]
        if all([straight_distances[j]>=minimum_walking_distance for j in sorted_index_tocheck]):
            # print(f"{i}/{data_addresses['totalFeatures']}")
            stop_code = 0
            distances_to_pt.append(minimum_walking_distance)
            closest_pt.append(closest_pt_index)
            straight_distances_to_pt.append(straight_distances[closest_pt_index])
            break
        J = [j for j in sorted_index_tocheck if straight_distances[j]<minimum_walking_distance]
        for j in J:
            stops_checked.append(j)
            walking_d = get_walking_distance(coordinates, stop_coordinates[j], straight_distances[j])
            if walking_d<minimum_walking_distance:
                closest_pt_index = j
                minimum_walking_distance = walking_d
    
    if stop_code:
        print(f"This shouldn't happen {i}")
    
address_lon = []
address_lat = []
stop_name = []
stop_lon = []
stop_lat = []
stop_type = []
for i in range(data_addresses['totalFeatures']):
    coordinates = data_addresses['features'][i]['geometry']['coordinates']
    address_lon.append(coordinates[0])
    address_lat.append(coordinates[1])
    
    stop_name.append(stop_names[closest_pt[i]])
    stop_type.append(req_stop_type)
    stop_lon.append(stop_coordinates[closest_pt[i]][0])
    stop_lat.append(stop_coordinates[closest_pt[i]][1])
    
df = pd.DataFrame(list(zip(address_lon, address_lat, stop_type, stop_name, stop_lon, stop_lat, distances_to_pt, straight_distances_to_pt)),columns =['address_lon', 'address_lat', 'pt_type', 'pt_name', 'pt_lon', 'pt_lat', 'walking_distance_pt', 'shortest_distance_pt'])
df.to_csv(f"closest_pt/closest_pt_{req_stop_type}_{district}.csv", index=False)
    