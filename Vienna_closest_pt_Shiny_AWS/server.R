library(shiny)
library(leaflet)
library(sf)
library(shinyjs)
library(ggplot2)
library(ggthemes)
library(stringr)

server <- function(input, output, session) {

    # Define a reactive expression to read the CSV file based on the current input values
    df <- reactive({
        read.csv(paste0("data/closest_pt_downsampled/closest_pt_", input$district, ".csv"))
    })
    
    df_full <- reactive({
      read.csv(paste0("data/closest_pt/closest_pt_", input$district, ".csv"))
    })
    
    click("show_areas")
    colors <- c("#e41a1c", "#377eb8", "#4daf4a", "#984ea3")
    
    # Define a reactive value for the color index
    color_index <- reactiveVal(1)
    
    # Define a reactive expression to track changes in input values
    input_changed <- reactive({
        list(input$district, input$pt_type, input$show_areas)
    })
    
    # Define a reactive expression for the map data
    map_data <- eventReactive(input$show_areas, {
        disable("show_areas")
        disable("district")
        disable("pt_type")
        disable("distance_slider")
        disable("color_selector")
        disable("clear_areas")
        
        req(input_changed())
        
        # Retrieve the current input values
        d <- input$distance_slider
        data <- df()
        
        progress <- shiny::Progress$new()
        # Make sure it closes when we exit this reactive, even if there's an error
        on.exit(progress$close())
        
        progress$set(message = "Computing areas", value = 0)
        
        # Filter rows based on the selected distance and transport type
        filtered_data <- data[data$walking_distance_pt <= d & data$pt_type == input$pt_type, ]
        
        # Create an sf object with circle geometries
        circles <- st_as_sf(filtered_data, coords = c("address_lon", "address_lat"), crs = 4326)
        progress$inc(0.3)
        circles <- st_simplify(circles, dTolerance = 30)
        progress$inc(0.3)
        circles <- st_buffer(circles, dist = 60, endCapStyle = "ROUND", nQuadSegs = 2)  # Buffer the circles for a better union
        progress$inc(0.3)
        # Find the union of all circles
        union_polygon <- st_union(circles)
        progress$inc(0.1)
        enable("show_areas")
        enable("district")
        enable("pt_type")
        enable("distance_slider")
        enable("color_selector")
        enable("clear_areas")
        list(data = data, union_polygon = union_polygon)
    })
    
    # Render the initial map output
    output$map <- renderLeaflet({
        leaflet() %>%
            addTiles() %>%
            fitBounds(lng1 = min(df()$address_lon), lat1 = min(df()$address_lat),
                      lng2 = max(df()$address_lon), lat2 = max(df()$address_lat)) 
            # %>% setMaxBounds(lng1 = min(df()$address_lon), lat1 = min(df()$address_lat),
            #              lng2 = max(df()$address_lon), lat2 = max(df()$address_lat))
    })
    
    # Observer for "Show areas" button
    observeEvent(input$show_areas, {
        # Check if the input values have changed
        req(input_changed())
        
        x <- as.integer(input$pt_type)+1
        pt_types <- list("Tram", "U-bahn", "Night bus", "Bus")
        
        # Get the current color from the vector
        current_color <- colors[color_index()]
        
        # Update the map output
        leafletProxy("map") %>%
            addPolygons(
                data = map_data()$union_polygon,
                # color = input$color_selector,
                color = current_color,
                fillOpacity = 0.3,
                weight = 1.5
            ) %>%
            addLegend(
                position = "bottomright",
                # colors = input$color_selector,
                colors = current_color,
                labels = paste0(pt_types[x], ": ", input$distance_slider,"m"),
                opacity = 0.5,
            )
        
        color_index(color_index() + 1)
        if (color_index() > length(colors)) {
            color_index(1)
        }
        
        # Update the addresses plot
        output$addresses_plot <- renderPlot({
            data <- df_full()
            selected_district <- input$district
            selected_d <- input$distance_slider
            
            # Define the color ranges and corresponding colors
            color_ranges <- c(-Inf, 0, 1, 2, 3)
            den_colors <- c("#e41a1c", "#377eb8", "#4daf4a", "#984ea3")
            labels <- c("Tram", "U-bahn", "Night bus", "Bus")
            
            # Create a factor variable for the color based on pt_type ranges
            data$color_group <- cut(data$pt_type, breaks = color_ranges, labels = FALSE, include.lowest = TRUE)
            
            # Plot the kernel density estimate using ggplot2
            ggplot(data, aes(x = walking_distance_pt, color = factor(color_group))) +
                stat_ecdf(geom = "step", size=1) +
                # geom_density(alpha = 0.5, size=1, bw = input$bandwidth) +
                # scale_color_manual(values = colors, aesthetics = "color", labels = labels, name = "") +
                scale_color_manual(values = colors, labels = labels, name = "") +
                labs(x = "Distance (metres)", y = "",
                     title = paste0("Fraction of addresses within ", selected_d, "m of a public transport stop in 1", str_pad(selected_district, 2, pad="0"), "0")) +
                geom_vline(xintercept = selected_d, linetype = "dashed", color = "black", size = 1) +
                theme_fivethirtyeight(base_size = 18) +
                theme(legend.position = c(0.85, 0.25)) +
                theme(plot.title = element_text(hjust = 0, size = rel(0.8), face = "plain")) +
                theme(axis.title.x = element_text(size = rel(0.8))) +
                theme(legend.direction = "vertical")
        })
        
    })
    
    # Observer for "Clear areas" button
    observeEvent(input$clear_areas, {
        leafletProxy("map") %>%
            clearShapes() %>%
            clearControls()
        color_index(1)
    })
}
