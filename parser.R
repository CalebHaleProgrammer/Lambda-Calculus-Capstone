isBindingToken <- function(token) {
  substr(token, 1, 1) %in% c("\\", "/","λ")
}

# ==============================================================================
# initializeAST
# Filters out "." separator tokens, creates a Root node, and attaches all
# remaining tokens as children in their original order.
# ==============================================================================
initializeAST <- function(tokens_list) {
  valid_tokens <- tokens_list[tokens_list != "."]
  if (length(valid_tokens) == 0) return(Node$new("Empty"))
  
  root <- Node$new("Root")
  for (token in valid_tokens) {
    root$children[[length(root$children) + 1]] <- Node$new(token)
  }
  return(root)
}

# ==============================================================================
# parseParen
# Collects all nodes between a matched parenthesis pair and places them as
# children of a new Group_Paren node. The group node replaces the paren range
# in parent_node's children at the same position. Existing subtrees of inner
# nodes are preserved because we move the node objects themselves, not copies.
# ==============================================================================
parseParen <- function(parent_node, left_idx, right_idx) {
  children <- as.list(parent_node$children)
  n        <- length(children)
  
  pre_nodes   <- if (left_idx > 1)            children[seq(1, left_idx - 1)]      else list()
  inner_nodes <- if (right_idx > left_idx + 1) children[seq(left_idx + 1, right_idx - 1)] else list()
  post_nodes  <- if (right_idx < n)           children[seq(right_idx + 1, n)]     else list()
  
  paren_node <- Node$new("Paren_Group")
  for (inner in inner_nodes) {
    paren_node$children[[length(paren_node$children) + 1]] <- inner
  }
  
  parent_node$children <- c(pre_nodes, list(paren_node), post_nodes)
}

# ==============================================================================
# parseBinding
# Collects a binding token and its two following siblings into a new
# Binding_Group node. The group replaces the three nodes in parent_node's
# children at the same starting position. Subtrees of all three are preserved.
# ==============================================================================
parseBinding <- function(parent_node, bind_idx) {
  children <- as.list(parent_node$children)
  n        <- length(children)
  
  #if (bind_idx + 2 > n) return(invisible(NULL))
  #This guard is redundant since reduceBinding now checks if there are two terms following a binding
  #The return(invisible(NULL)) is R's idiomatic way of saying "exit early, return nothing meaningful, and don't print anything." Since parseBinding modifies parent_node in place and the caller doesn't use its return value, returning NULL here is clean and safe.
  
  pre_nodes     <- if (bind_idx > 1)      children[seq(1, bind_idx - 1)]      else list()
  binding_nodes <- children[seq(bind_idx, bind_idx + 2)]
  post_nodes    <- if (bind_idx + 3 <= n) children[seq(bind_idx + 3, n)]      else list()
  
  binding_node <- Node$new("Binding_Group")
  for (member in binding_nodes) {
    binding_node$children[[length(binding_node$children) + 1]] <- member
  }
  
  parent_node$children <- c(pre_nodes, list(binding_node), post_nodes)
}

# ==============================================================================
# reduceParentheses
# Scans only node's immediate children (not deeper). Tracks the rightmost "("
# seen so far; when a ")" is found, the most recent "(" forms an innermost
# pair and is resolved via parseParen. Repeats until no parentheses remain
# at this level. Scanning from inside-out naturally handles nesting: inner
# pairs are always resolved before outer ones reach a closing ")".
# ==============================================================================
reduceParentheses <- function(node) {
  repeat {
    children       <- as.list(node$children)
    rightmost_left <- NULL
    found_pair     <- FALSE
    
    for (i in seq_along(children)) {
      token <- children[[i]]$name
      
      if (token == "(") {
        rightmost_left <- i
        
      } else if (token == ")") {
        if (is.null(rightmost_left)) stop("Parse Error: unmatched right parenthesis")
        parseParen(node, rightmost_left, i)
        found_pair <- TRUE
        break  # restart scan against the updated children list
      }
    }
    
    if (!found_pair) {
      if (!is.null(rightmost_left)) stop("Parse Error: unmatched left parenthesis")
      break  # no parentheses remain at this level
    }
  }
}

# ==============================================================================
# reduceBindings
# Scans node's immediate children left to right. On finding a binding token,
# groups it and its two following siblings via parseBinding and restarts.
# Repeats until no binding terms remain at this level.
# ==============================================================================
reduceBindings <- function(node) {
  repeat {
    children      <- as.list(node$children)
    found_binding <- FALSE
    
    for (i in rev(seq_along(children))) {
      if (isBindingToken(children[[i]]$name)) {
        # Only attempt if two following siblings exist
        if (i + 2 <= length(children)) {
          parseBinding(node, i)
          found_binding <- TRUE
          break
        }
      }
    }
    
    if (!found_binding) break
  }
}

# ==============================================================================
# processNode
# Reduces parentheses then bindings in node's immediate children, then
# recurses into each child. Parentheses are resolved before bindings so that
# a grouped expression can appear as the argument or body of a binding.
# ==============================================================================
processNode <- function(node) {
  if (node$name != "Binding_Group") {
    reduceParentheses(node)
    reduceBindings(node)
  }
  for (child in as.list(node$children)) {
    processNode(child)
  }
}

# ==============================================================================
# parse_lambda
# Entry point. Builds the initial flat AST from the token list, then
# processes it into a fully parsed tree.
# ==============================================================================
parse_lambda <- function(tokens_list) {
  ast <- initializeAST(tokens_list)
  processNode(ast)
  return(ast)
}

# ==============================================================================
# identifyBindingGroups
# Post-processing step called after parse_lambda. Walks the entire tree and
# 1. renames any Paren_Group or Root node to Binding_Group if it has a bindingTerm
# and at least one more node as children,
# 2. Collapses redundant parenthesis-binding-group layers (extra layers added by readable expressions)
# This allows Paren_Group and Root nodes that contain a complete function
# expression to be treated as binding groups for evaluation and display.
# ==============================================================================
identifyBindingGroups <- function(node) {
  children <- as.list(node$children)
  
  # --- Case 1: relabel ---
  if (node$name %in% c("Paren_Group", "Root") &&
      length(children) >= 2 &&
      getNodeRole(children[[1]]$name) == "bindingTerm") {
    node$name <- "Binding_Group"
  }
  
  # --- Case 2: collapse redundant single-child wrappers ---
  # Re-fetch children since Case 1 may have changed node$name (not children)
  children <- as.list(node$children)
  for (i in seq_along(children)) {
    child <- children[[i]]
    if (child$name == "Paren_Group") {
      grandchildren <- as.list(child$children)
      if (length(grandchildren) == 1 &&
          grandchildren[[1]]$name == "Binding_Group") {
        node$children[[i]] <- grandchildren[[1]]
      }
    }
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
