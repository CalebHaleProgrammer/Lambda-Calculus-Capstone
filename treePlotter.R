library(igraph)
library(data.tree)

# ==============================================================================
# astToEdgeList
# Walks the data.tree recursively and records every parent->child edge as a pair of unique node IDs.
#
# Returns a list with:
#   $edges   — a 2-column data frame: from_id, to_id
#   $labels  — a named character vector: id -> display label
#
# Syntax tokens "(", ")" are dropped entirely just in case any got through the parser
# ==============================================================================

SPECIAL_NAMES <- c("Paren_Group", "Binding_Group", "Root")
NodeDisplayText = list(Paren_Group= "( )", Binding_Group="f(x)", Root= "")#I think convention might prefer `Paren_Group` etc. as strings when it will be looked up by strings, but R understands this anyway
DROP_NAMES   <- c("(", ")")

# Node type classifier — used both for sizing and future coloring
getNodeRole <- function(name) {
  if (name == "Binding_Group")                return("functionAbstraction")
  if (name == "Paren_Group")                  return("parenGroup")
  if (name == "Root")                         return("root")
  if (substr(name, 1, 1) %in% c("\\", "/"))  return("bindingTerm")
  return("term")
}

astToEdgeList <- function(node,
                          parent_id  = NULL,
                          counter    = new.env(parent = emptyenv()),
                          edges      = list(),
                          labels     = character(0),
                          roles     = character(0)) {
  
  # --- assign a unique integer ID to this node ---
  # new.env + counter$n is a simple way to share a mutable counter
  # across recursive calls without returning it every time.
  if (is.null(counter$n)) counter$n <- 0L
  counter$n  <- counter$n + 1L
  my_id      <- counter$n
  
  # --- decide display label ---
  raw_name   <- node$name
  if (raw_name %in% DROP_NAMES) return(list(edges = edges, labels = labels, roles = roles))
  display <- if (raw_name %in% SPECIAL_NAMES) NodeDisplayText[[raw_name]] else raw_name #to lookup the alternate display text. []gets a list (pair) from the named list, [[]] gets the actual value
  labels[as.character(my_id)] <- display
  roles[as.character(my_id)]  <- getNodeRole(raw_name)
  
  # --- record edge from parent to me ---
  if (!is.null(parent_id)) {
    edges <- c(edges, list(c(from = parent_id, to = my_id)))
  }
  
  # --- recurse into children ---
  for (child in as.list(node$children)) {
    result <- astToEdgeList(child,
                            parent_id = my_id,
                            counter   = counter,
                            edges     = edges,
                            labels    = labels,
                            roles     = roles)
    edges  <- result$edges
    labels <- result$labels
    roles  <- result$roles
  }
  
  return(list(edges = edges, labels = labels, roles=roles))
}

# ==============================================================================
# buildIgraph
# Converts the edge list from astToEdgeList into an igraph object,
# attaching the display labels as a vertex attribute called "label".
# ==============================================================================

buildIgraph <- function(ast) {
  raw     <- astToEdgeList(ast)
  
  if (length(raw$edges) == 0) {
    # Edge case: single-node tree (empty or one token)
    g <- make_empty_graph(n = 1, directed = TRUE)
    V(g)$label <- raw$labels[["1"]]
    V(g)$nodeRole  <- raw$roles[["1"]]
    return(g)
  }
  
  # Stack the edge pairs into a 2-column matrix
  edge_matrix <- do.call(rbind, raw$edges)   # each row: c(from=N, to=M)
  
  # When there is only one edge, do.call(rbind) produces a named vector
  # instead of a matrix, and t() then transposes it the wrong way.
  # matrix(..., ncol = 2) forces the correct shape regardless of row count.
  edge_matrix <- matrix(edge_matrix, ncol = 2)
  
  # igraph wants a flat vector: c(from1,to1, from2,to2, ...)
  g <- make_graph(as.vector(t(edge_matrix)), directed = TRUE)
  
  # Attach labels in vertex-ID order
  n_vertices      <- vcount(g)
  V(g)$label     <- ifelse(is.na(raw$labels[as.character(seq_len(n_vertices))]), "",
                           raw$labels[as.character(seq_len(n_vertices))])
  V(g)$nodeRole <- raw$roles[as.character(seq_len(n_vertices))]
  
  return(g)
}

debugAST <- function(ast) {
  raw         <- astToEdgeList(ast)
  edge_matrix <- do.call(rbind, raw$edges)
  edge_matrix <- matrix(edge_matrix, ncol = 2)
  cat("Edge matrix:\n")
  print(edge_matrix)
  cat("Flat edge vector:\n")
  print(as.vector(t(edge_matrix)))
  cat("Labels:\n")
  print(raw$labels)
  cat("nodeRoles:\n")
  print(raw$roles)
}
# ==============================================================================
# plotAST
# Plots the igraph object as a top-down tree using the Reingold-Tilford
# layout, which is designed specifically for trees.
#
# Vertex styling:
#   - Token nodes  : filled circle, label shown
#   - Group nodes  : smaller, light gray (structural, no label)
# colorScheme is a named list with entries: root, binding, token, group
# Each entry is a hex color string. Defaults to a single neutral blue.
# igraph does not auto-size nodes for text. We estimate width from label
# length and convert to igraph's size units (which are roughly "% of plot
# width"). nchar() gives character count; multiplying by a scale factor
# and adding padding gives a reasonable circle radius for each label.
# ==============================================================================

plotAST <- function(ast, title = "Lambda Calculus AST",
                    labelStructural  = FALSE,
                    colorScheme = list(root    = "#AAAAAA",
                                       bindingTerm = "#5B8DB8",
                                       term   = "#5B8DB8",
                                       functionAbstraction   = "#AAAAFF",
                                       parenGroup   = "#AAAAAA",
                                       labelColor          = "#FFFFFF")) {
  g      <- buildIgraph(ast)
  labels <- V(g)$label
  nodeRole  <- V(g)$nodeRole
  
  is_group <- labels == ""   # TRUE for Paren_Group / Binding_Group nodes
  
  # Reingold-Tilford layout: designed for trees, top-down with root=1
  layout <- layout_as_tree(g, root = 1, mode = "out", flip.y = TRUE)
  
  # Node labels
  is_structural <- nodeRole %in% c("parenGroup", "functionAbstraction", "root")
  v_label       <- ifelse(is_structural & !labelStructural, "", labels)                                   # "" for groups
  
  # --- node sizing ---
  # Base size covers short labels; the nchar() term adds width per character.
  # Group nodes (blank label) stay small since they show no text.
  char_count <- nchar(labels)
  v_size     <- ifelse(nodeRole %in% c("parenGroup", "functionAbstraction", "root"),
                       16,
                       pmax(20, char_count * 4.5 + 10))
  
  # --- colors from scheme ---
  #sapply here means "apply this function to every element of nodeRole and collect the results into a vector" — so it maps each role string to its corresponding color from colorScheme
  v_color <- sapply(nodeRole, function(r) colorScheme[[r]])
  
  # --- label color: white on darker nodes, hidden on group nodes ---
  #v_label_color <- ifelse(nodeRole %in% c("parenGroup", "functionAbstraction"), "#AAAAAA", "white")
  
  #structural nodes (no label) get their own color so the "" doesn't show
  #v_label_color <- ifelse(
  #  nodeRole %in% c("parenGroup", "functionAbstraction", "root"),
  #  colorScheme[["parenGroup"]],   # invisible against node color
  #  colorScheme[["labelColor"]]
  #)
  v_label_color <- ifelse(
    is_structural & !labelStructural,
    colorScheme[["parenGroup"]],
    colorScheme[["labelColor"]]
  )
  
  plot(
    g,
    layout            = layout,
    vertex.color      = v_color,
    vertex.size       = v_size,
    vertex.label      = v_label,
    vertex.label.color = v_label_color,
    vertex.label.cex  = 1.4,
    vertex.frame.color = NA,          # no border ring on nodes
    edge.arrow.size   = 0.3,
    edge.color        = "#888888",
    main              = title
  )
}

# ==============================================================================
# identifyBindingGroups
# Post-processing step called after parse_lambda. Walks the entire tree and
# renames any Paren_Group or Root node to Binding_Group if it has exactly
# three children where the first child is a bindingTerm.
# This allows Paren_Group and Root nodes that contain a complete function
# expression to be treated as binding groups for evaluation and display.
# ==============================================================================
identifyBindingGroups <- function(node) {
  children <- as.list(node$children)
  
  if (node$name %in% c("Paren_Group", "Root") &&
      length(children) >= 2 &&
      getNodeRole(children[[1]]$name) == "bindingTerm") {
    node$name <- "Binding_Group"
  }
  
  for (child in children) {
    identifyBindingGroups(child)
  }
  
  invisible(node)  # invisible() returns the value but suppresses auto-printing
  #since data.tree nodes are modified in place, unlike most R objects which are copied, 
  #the function modifies the tree directly without needing to pass the result back up
}

# ==============================================================================
# viewAST   Prints the AST to the console with indentation showing tree depth.
# ==============================================================================
viewAST <- function(node, depth = 0) {
  cat(strrep("  ", depth), node$name, "\n", sep = "")
  for (child in as.list(node$children)) {
    viewAST(child, depth + 1)
  }
}