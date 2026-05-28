# Install if needed:
# install.packages(c("igraph", "data.tree"))
library(igraph)
library(data.tree)

# ==============================================================================
# astToEdgeList
# Walks the data.tree recursively (same logic as viewAST) and records
# every parent->child edge as a pair of unique node IDs.
#
# Returns a list with:
#   $edges   — a 2-column data frame: from_id, to_id
#   $labels  — a named character vector: id -> display label
#
# Group nodes (Paren_Group, Binding_Group) get an empty string label.
# Syntax tokens "(", ")" are dropped entirely (they become group nodes
# in your parser, so they shouldn't appear in a parsed tree anyway,
# but this guards against it).
# ==============================================================================

HIDDEN_NAMES <- c("Paren_Group", "Binding_Group")
DROP_NAMES   <- c("(", ")")

astToEdgeList <- function(node,
                          parent_id  = NULL,
                          counter    = new.env(parent = emptyenv()),
                          edges      = list(),
                          labels     = character(0)) {
  
  # --- assign a unique integer ID to this node ---
  # new.env + counter$n is a simple way to share a mutable counter
  # across recursive calls without returning it every time.
  if (is.null(counter$n)) counter$n <- 0L
  counter$n  <- counter$n + 1L
  my_id      <- counter$n
  
  # --- decide display label ---
  raw_name   <- node$name
  if (raw_name %in% DROP_NAMES) return(list(edges = edges, labels = labels))
  display    <- if (raw_name %in% HIDDEN_NAMES) "" else raw_name
  labels[as.character(my_id)] <- display
  
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
                            labels    = labels)
    edges  <- result$edges
    labels <- result$labels
  }
  
  return(list(edges = edges, labels = labels))
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
    return(g)
  }
  
  # Stack the edge pairs into a 2-column matrix
  edge_matrix <- do.call(rbind, raw$edges)   # each row: c(from=N, to=M)
  
  # igraph wants a flat vector: c(from1,to1, from2,to2, ...)
  g <- make_graph(as.vector(t(edge_matrix)), directed = TRUE)
  
  # Attach labels in vertex-ID order
  n_vertices      <- vcount(g)
  ordered_labels  <- raw$labels[as.character(seq_len(n_vertices))]
  V(g)$label      <- ifelse(is.na(ordered_labels), "", ordered_labels)
  
  return(g)
}

# ==============================================================================
# plotAST
# Plots the igraph object as a top-down tree using the Reingold-Tilford
# layout, which is designed specifically for trees.
#
# Vertex styling:
#   - Token nodes  : filled circle, label shown
#   - Group nodes  : smaller, light gray (structural, no label)
# ==============================================================================

plotAST <- function(ast, title = "Lambda Calculus AST") {
  g      <- buildIgraph(ast)
  labels <- V(g)$label
  
  is_group <- labels == ""   # TRUE for Paren_Group / Binding_Group nodes
  
  # Reingold-Tilford layout: designed for trees, top-down with root=1
  layout <- layout_as_tree(g, root = 1, mode = "out", flip.y = TRUE)
  
  # Per-vertex visual properties
  v_color <- ifelse(is_group, "#CCCCCC", "#4A90D9")   # gray vs blue
  v_size  <- ifelse(is_group, 8, 18)                   # smaller for groups
  v_label <- labels                                     # "" for groups
  v_label_color <- "white"
  
  plot(
    g,
    layout            = layout,
    vertex.color      = v_color,
    vertex.size       = v_size,
    vertex.label      = v_label,
    vertex.label.color = v_label_color,
    vertex.label.cex  = 0.85,
    vertex.frame.color = NA,          # no border ring on nodes
    edge.arrow.size   = 0.3,
    edge.color        = "#888888",
    main              = title
  )
}