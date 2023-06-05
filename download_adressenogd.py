import os
import urllib.request, json 

if not os.path.exists("ADRESSENOGD"):
    os.makedirs("ADRESSENOGD")

for i in range(1, 24):
    with urllib.request.urlopen(f"https://data.wien.gv.at/daten/geo?service=WFS&request=GetFeature&version=1.1.0&typeName=ogdwien:ADRESSENOGD&srsName=EPSG:4326&outputFormat=json&cql_filter=GEB_BEZIRK=%27{i:02d}%27") as url:
        data = json.load(url)
    with open(f"ADRESSENOGD/ADRESSENOGD_1{i:02d}0.json", "w") as outfile:
        json.dump(data, outfile)