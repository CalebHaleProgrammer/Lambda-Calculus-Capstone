library(shiny)
library(colourpicker)  # install.packages("colourpicker") if needed
library(igraph)
library(data.tree)

source("lexer.R")
source("parser.R")
source("treePlotter.R")
source("alphaEquivalence.R")
source("interpreter.R")

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
  "not (full): \\p. p (\\x. \\y. y) (\\x. \\y. x)"    = "\\p. p (\\x. \\y. y) (\\x. \\y. x)",
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
    .hypergraph-node {
      border: 1px solid #ccc;
      border-radius: 4px;
      padding: 4px;
      margin: 2px;
      cursor: pointer;
      background: #f9f9f9;
      font-family: monospace;
      font-size: 11px;
      white-space: pre;
    }
    .hypergraph-node:hover { background: #e8f0fe; }
    .hypergraph-node.selected { border-color: #4A90D9; background: #e8f0fe; }
    .hypergraph-node.loop { opacity: 0.4; }
    .hypergraph-node.recursing { display: none; }
    .hypergraph-node.maxDepth { border-color: #E57373; }
    .solution-box {
      margin-top: 12px;
      padding: 8px 12px;
      background: #f5f5f5;
      border-radius: 4px;
      font-family: monospace;
    }
  ")),
  
  sidebarLayout(
    position = "right",
    sidebarPanel(
      width = 3,
      
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
      helpText("Spaces between tokens are required. Use \\, /, or λ for lambda. Period immediately after binding term, (optional)."),
      
      checkboxInput("labelStructural", "Label structural nodes", value = FALSE), #toggles f(x) display
      checkboxInput("autoRun", "Auto-run interpreter on update", value = FALSE),
      
      hr(),
      h4("Interpreter"),
      numericInput("maxDepth", "Max depth", value = 20, min = 1, max = 100),
      actionButton("runBtn", "Run interpreter", width = "100%"),
      
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
      width = 9,
      fluidRow(
        # Left: hyper-graph panel
        column(6,
               h4("Evaluation graph"),
               uiOutput("hyperGraphUI"),
               div(class = "solution-box",
                   strong("Solution(s):"),
                   verbatimTextOutput("solutionText")
               )
        ),
        # Right: single AST view
        column(6,
               h4("AST view"),
               plotOutput("astPlot", height = "500px"),
               verbatimTextOutput("errorMsg")
        )
      )
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
    ast    <- parse_lambda(tokens)
    identifyBindingGroups(parse_lambda(tokens))
  })
  
  # --- Color scheme ---
  colorScheme <- reactive({
    list(
      root                = input$col_root,
      bindingTerm         = input$col_bindingTerm,
      term                = input$col_term,
      functionAbstraction = input$col_functionAbstraction,
      parenGroup          = input$col_parenGroup,
      labelColor          = input$col_label
    )
  })
  
  # --- Trigger interpreter ---
  # runTrigger fires when the Run button is clicked OR when the parsed
  # AST changes and autoRun is checked.
  # reactiveVal holds a single mutable value; incrementing it signals
  # that a new run is needed without caring what the value actually is.
  runTrigger <- reactiveVal(0)
  
  observeEvent(input$runBtn, {
    runTrigger(runTrigger() + 1)
  })
  
  observeEvent(parsedAST(), {
    if (isTRUE(input$autoRun)) runTrigger(runTrigger() + 1)
  })
  
  # --- Build hyper-graph ---
  # isolate(parsedAST()) reads the AST without making hyperGraph reactive
  # to parsedAST directly — it only re-runs when runTrigger changes.
  hyperGraph <- eventReactive(runTrigger(), {
    req(parsedAST())
    ast <- tryCatch(isolate(parsedAST()), error = function(e) NULL)
    req(ast)
    buildHyperGraph(ast, maxDepth = input$maxDepth)
  })
  
  # --- Track selected hyper-graph node ---
  selectedNodeId <- reactiveVal(NULL)
  
  # Reset selection when a new graph is built
  observeEvent(hyperGraph(), {
    selectedNodeId(NULL)
  })
  
  # Receive click from hyper-graph UI
  observeEvent(input$hyperNodeClick, {
    selectedNodeId(input$hyperNodeClick)
  })
  
  
  # --- Render the plot ---
  # renderPlot re-runs whenever any reactive value it reads changes —
  # so it redraws on new expression OR on any color change automatically.
  output$astPlot <- renderPlot({
    scheme <- colorScheme()
    ast <- tryCatch({
      sid <- selectedNodeId()
      if (!is.null(sid) && !is.null(hyperGraph())) {
        hyperGraph()[[as.character(sid)]]$ast
      } else {
        parsedAST()
      }
    }, error = function(e) NULL) #if parsing fails, return null
    
    req(ast)
    plotAST(ast,
            labelStructural = input$labelStructural,
            colorScheme     = scheme)
  })
  
  
  # --- Show errors to the user ---
  output$errorMsg <- renderText({
    tryCatch({ parsedAST(); "" },
             error = function(e) paste("Parse error:", e$message))
  })
  
  # --- Hyper-graph UI ---
  # Renders the hyper-graph as HTML with clickable node cards.
  # Each card shows the viewAST text for that AST.
  # JavaScript sends the clicked node id to input$hyperNodeClick.
  output$hyperGraphUI <- renderUI({
    graph <- tryCatch(hyperGraph(), error = function(e) NULL)
    req(graph)
    
    # Build HTML for each node
    nodeCards <- lapply(graph, function(rec) {
      if (rec$status == "recursing") return(NULL)
      
      astText <- capture.output({
        viewAST(rec$ast)
      })
      astText <- paste(astText, collapse = "\n")
      
      cssClass <- paste("hypergraph-node", rec$status)
      if (!is.null(selectedNodeId()) &&
          rec$id == as.integer(selectedNodeId())) {
        cssClass <- paste(cssClass, "selected")
      }
      
      # Each card is a div that on click calls Shiny.setInputValue
      # to send the node id back to the server
      tags$div(
        class   = cssClass,
        onclick = sprintf(
          "Shiny.setInputValue('hyperNodeClick', %d, {priority: 'event'})",
          rec$id
        ),
        # Show "..." for direct children of branching nodes above recursing chains
        if (any(sapply(graph[as.character(rec$children)],
                       function(c) !is.null(c) && c$status == "recursing"))) {
          tags$div(astText, tags$div("  ..."))
        } else {
          astText
        }
      )
    })
    
    # Filter NULLs (recursing nodes)
    nodeCards <- Filter(Negate(is.null), nodeCards)
    do.call(tags$div, nodeCards)
  })
  
  # --- Solution text ---
  output$solutionText <- renderText({
    graph <- tryCatch(hyperGraph(), error = function(e) NULL)
    req(graph)
    
    # Leaf nodes are normal-status nodes with no children
    leaves <- Filter(function(rec) {
      rec$status == "normal" && length(rec$children) == 0
    }, graph)
    
    if (length(leaves) == 0) return("No normal-form solutions found.")
    
    exprs <- sapply(leaves, function(rec) reconstructExpression(rec$ast))
    paste(exprs, collapse = "\n")
  })
}

shinyApp(ui = ui, server = server)

#Notes:
#reactiveVal(0) creates a single mutable reactive value. Calling it with no argument reads it; calling it with an argument sets it. Incrementing it is a common Shiny pattern for "trigger something without caring about the value."
#eventReactive(trigger, {...}) is like reactive but only re-runs when trigger changes, not when other reactive values it reads change. This lets the hyper-graph build only on demand.
#isolate(parsedAST()) reads a reactive value without creating a reactive dependency — so hyperGraph doesn't automatically re-run when parsedAST changes, only when runTrigger fires.
#capture.output({...}) captures anything printed to the console by the code inside it and returns it as a character vector — used here to capture viewAST's printed output as text for the node cards.
#Shiny.setInputValue(...) is JavaScript that sends a value from the browser back to the R server, used here so clicking a node card updates input$hyperNodeClick.
