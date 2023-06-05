library(shiny)
library(leaflet)
library(shinyjs)
library(waiter)

districts <- seq(1, 23, 1)
names(districts) <- as.character(seq(from = 1010, to = 1230, by = 10))

pt_types <- list(0, 1, 2, 3)
names(pt_types) <- c("Tram", "U-bahn", "Night bus", "Bus")

ui <- fluidPage(
    # useWaiter(),
    # waiterOnBusy(),
    useShinyjs(), 
    theme = bslib::bs_theme(bootswatch = "cosmo"), # cosmo
    titlePanel("How close is public transport in Vienna?"),
    withTags({
        div(class="header", checked=NA,
            h5("An interactive exploration of public transport access by distance and type in Vienna"),
            p("Select a district, a public transport type and a distance threshold, and then click 'Show areas'. You can plot multiple areas by changing transport type and distance threshold and clicking 'Show areas' again. Click 'Clear areas' to restart."),
            p("Note: some districts and larger distance thresholds take longer time to compute the areas."),
        )
    }),
    sidebarLayout(
        sidebarPanel(
            selectInput("district", "Select district:", choices = districts),
            selectInput("pt_type", "Select public transport:", choices = pt_types, selected=0),
            sliderInput("distance_slider", "Select distance (metres):", min = 0, max = 1000, value = 200, step = 10),
            # textInput("color_index_input", label = "Color Index:", value = "1", width = "100%"),
            actionButton("show_areas", "Show areas"),
            actionButton("clear_areas", "Clear areas")
        ),
        mainPanel(
            plotOutput("addresses_plot")
        )
    ),
    hr(),
    fluidRow(
      column(12, 
        leafletOutput("map")
      ),
    )
)