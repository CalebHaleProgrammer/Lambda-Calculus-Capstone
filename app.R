library(shiny)
library(colourpicker)  # install.packages("colourpicker") if needed
library(igraph)
library(data.tree)

source("lexer.R")
source("parser.R")
source("treePlotter.R")

options(shiny.launch.browser = TRUE)

PRESETS <- list(
  "Identity: \\x. x"                     = "\\x. x",
  "Constant: \\x. y"               = "\\x. y",
  "Application: (\\x. x b) a"              = "(\\x. x b) a",
  "true: \\x. \\y. x"    = "\\x. \\y. x",
  "false: \\x. \\y. y"    = "\\x. \\y. y",
  "and: \\p. \\q. p q p"    = "\\p. \\q. p q p",
  "or: \\p. \\q. p q p"    = "\\p. \\q. p p q",
  "not: \\p. p false true"    = "\\p. p false true",
  "if: \\p. \\a. \\b. p a b"    = "\\p. \\a. \\b. p a b"
)

# ==============================================================================
# UI
# fluidPage creates a standard responsive page layout.
# sidebarLayout with positions = "right" puts controls on the right.
# ==============================================================================
ui <- fluidPage(
  titlePanel("Lambda Calculus AST Viewer"),
  
  tags$style(HTML("
    .color-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 4px 12px;
    }
    .color-grid .form-group { margin-bottom: 6px; }
    .colour-input .form-control { height: 28px; padding: 2px 6px; font-size: 12px; }
    .colour-input label { font-size: 12px; margin-bottom: 2px; }
  ")),
  
  sidebarLayout(
    position = "right",
    
    sidebarPanel(
      width = 4,
      
      h4("Expression"),
      selectInput(
        inputId = "preset",
        label   = "Load a preset",
        choices = c("-- type your own --", names(PRESETS))
      ),
      textInput(
        inputId     = "expression",
        label       = "Token string",
        placeholder = "e.g.  \\x . x"
      ),
      helpText("Spaces between tokens are required. Use \\ or / for lambda."),
      
      checkboxInput("labelStructural", "Label structural nodes", value = FALSE), #toggles f(x) display
      
      hr(),
      
      h4("Node colors"),
      # tags$div with a class lets us apply the two-column CSS grid above
      tags$div(class = "color-grid",
               colourInput("col_root",                "Root",
                           value = "#AAAAAA", showColour = "background"),
               colourInput("col_bindingTerm",         "Binding term",
                           value = "#5B8DB8", showColour = "background"),
               colourInput("col_term",                "Term",
                           value = "#5B8DB8", showColour = "background"),
               colourInput("col_functionAbstraction", "Function abstraction",
                           value = "#AAAAAA", showColour = "background"),
               colourInput("col_parenGroup",          "Paren group",
                           value = "#AAAAAA", showColour = "background"),
               colourInput("col_label",               "Label text",
                           value = "#FFFFFF", showColour = "background")
      ),
      
      hr(),
      actionButton("resetColors", "Reset colors")
    ),
    
    mainPanel(
      width = 8,
      plotOutput("astPlot", height = "600px"),
      verbatimTextOutput("errorMsg")
    )
  )
)

# ==============================================================================
# Server
# input$x reads a UI control value.
# output$x <- renderY({...}) defines what gets sent back to the UI.
# observeEvent(input$x, {...}) runs a block whenever input$x changes.
# ==============================================================================
server <- function(input, output, session) {
  
  # --- Autofill text box when a preset is chosen ---
  # observeEvent watches a single input and fires only when it changes.
  observeEvent(input$preset, {
    if (input$preset != "-- type your own --") {
      # updateTextInput pushes a new value to the text box from the server side
      updateTextInput(session, "expression", value = PRESETS[[input$preset]])
    }
  })
  
  # --- Reset colors to defaults ---
  observeEvent(input$resetColors, {
    updateColourInput(session, "col_root",                value = "#AAAAAA")
    updateColourInput(session, "col_bindingTerm",         value = "#5B8DB8")
    updateColourInput(session, "col_term",                value = "#5B8DB8")
    updateColourInput(session, "col_functionAbstraction", value = "#AAAAAA")
    updateColourInput(session, "col_parenGroup",          value = "#AAAAAA")
    updateColourInput(session, "col_label", value = "#FFFFFF")
  })
  
  # --- Reactive expression that parses the input string ---
  # reactive({...}) is like a function that caches its result and only
  # re-runs when one of the input values it reads has changed.
  # This one re-runs whenever input$expression changes.
  parsedAST <- reactive({
    req(input$expression)  # req() pauses execution if the value is empty
    expr <- trimws(input$expression)
    req(nchar(expr) > 0)
    tokens <- LexerTokenize(expr)
    identifyBindingGroups(parse_lambda(tokens))
  })
  
  # --- Render the plot ---
  # renderPlot re-runs whenever any reactive value it reads changes —
  # so it redraws on new expression OR on any color change automatically.
  output$astPlot <- renderPlot({
    ast <- tryCatch(
      parsedAST(),
      error = function(e) NULL   # if parsing fails, return NULL
    )
    
    if (is.null(ast)) return()   # blank plot on error
    
    scheme <- list(
      root                = input$col_root,
      bindingTerm         = input$col_bindingTerm,
      term                = input$col_term,
      functionAbstraction = input$col_functionAbstraction,
      parenGroup          = input$col_parenGroup,
      labelColor          = input$col_label
    )
    
    plotAST(ast, labelStructural = input$labelStructural, colorScheme = scheme)
  })
  
  # --- Show parse errors to the user ---
  output$errorMsg <- renderText({
    tryCatch({
      parsedAST()
      ""
    }, error = function(e) {
      paste("Parse error:", e$message)
    })
  })
}

shinyApp(ui = ui, server = server)