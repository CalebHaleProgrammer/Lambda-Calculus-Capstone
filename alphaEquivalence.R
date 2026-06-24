# Provides alpha-equivalence checking for lambda calculus ASTs.
# Two ASTs are alpha-equivalent if they have the same structure and free variables, but may differ in bound variable names.
#
# Approach:
#   1. normalizeNames() walks the tree depth-first and renames all bound variables to canonical names (x1, x2, ...) in the order they are bound. Free variables are left as-is.
#   2. astEqual() compares two normalized trees structurally.

# ==============================================================================
# Takes a variable name and returns a new name with its numeric suffix
# incremented. If the name has no numeric suffix, appends 1.
incrementName <- function(name) {
  # gregexpr finds the position of the numeric suffix if one exists.
  # We look for one or more digits at the end of the string using $.
  match <- regmatches(name, regexpr("[0-9]+$", name))
  if (length(match) == 0 || match == "") {
    return(paste0(name, "1"))
  }
  base   <- substr(name, 1, nchar(name) - nchar(match))
  number <- as.integer(match) + 1L
  paste0(base, number)
}

# ==============================================================================
# normalizeNames
# Walks the AST depth-first and renames bound variables to canonical names.
# 
# env is a named character vector mapping original names to canonical names
# for all variables bound in the current scope. It is passed down into
# children and extended when a new binding is encountered.
#
# counter is a shared mutable environment (same pattern as astToEdgeList)
# so that canonical names are globally unique across the whole tree
# (x1, x2, x3 ... rather than resetting per scope).
#
# Returns a Clone() of the input with renamed nodes — does not modify
# the original.
# ==============================================================================
normalizeNames <- function(node,
                           env     = character(0),
                           counter = new.env(parent = emptyenv())) {
  if (is.null(counter$n)) counter$n <- 0L
  result <- Clone(node)
  normalizeNamesInPlace(result, env, counter)
  result
}

normalizeNamesInPlace <- function(node, env, counter) {
  children <- as.list(node$children)
  
  if (node$name == "Binding_Group" && length(children) == 3) {
    bindingName <- children[[1]]$name
    # Strip the leading \ or / to get the variable name
    varName     <- substr(bindingName, 2, nchar(bindingName))
    
    # Assign a fresh canonical name for this bound variable
    counter$n   <- counter$n + 1L
    canonical   <- paste0("_v", counter$n)
    
    # Extend the environment for this scope
    newEnv            <- env
    newEnv[varName]   <- canonical
    
    # Rename the binding term node itself
    node$children[[1]]$name <- paste0(
      substr(bindingName, 1, 1),  # preserve \ or /
      canonical
    )
    
    # Recurse into body (child 2) and input (child 3) with extended env
    normalizeNamesInPlace(node$children[[2]], newEnv, counter)
    normalizeNamesInPlace(node$children[[3]], newEnv, counter)
    
  } else {
    # For non-binding nodes, rename free variable references if in scope,
    # then recurse into all children with the same env
    if (getNodeRole(node$name) == "term" && node$name %in% names(env)) {
      node$name <- env[[node$name]]
    }
    for (child in as.list(node$children)) {
      normalizeNamesInPlace(child, env, counter)
    }
  }
}

# ==============================================================================
# Compares two ASTs structurally after normalizing both.Returns TRUE if they are alpha-equivalent, FALSE otherwise.
astEqual <- function(ast1, ast2) {
  n1 <- normalizeNames(ast1)
  n2 <- normalizeNames(ast2)
  treeEqual(n1, n2)
}

# ==============================================================================
# Recursive structural comparison of two already-normalized trees.Compares node names and recursively compares children pairwise.
treeEqual <- function(node1, node2) {
  if (node1$name != node2$name) return(FALSE)
  
  children1 <- as.list(node1$children)
  children2 <- as.list(node2$children)
  
  if (length(children1) != length(children2)) return(FALSE)
  
  for (i in seq_along(children1)) {
    if (!treeEqual(children1[[i]], children2[[i]])) return(FALSE)
  }
  
  TRUE
}