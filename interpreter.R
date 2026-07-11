# ==============================================================================
# interpreter.R
# Beta reduction and hyper-graph construction for lambda calculus ASTs.
#
# Main entry point: buildHyperGraph(ast)
# Returns a list of records, each representing one AST node in the hyper-graph.
#
# Each record:
#   $id       — unique integer
#   $ast      — the data.tree AST
#   $parents  — integer vector of parent record ids
#   $children — integer vector of child record ids
#   $status   — "normal", "loop", "maxDepth", or "recursing"
#   $depth    — integer, 0 for the root
#   $reduction — which binding group index was reduced to produce this node
# ==============================================================================

source("alphaEquivalence.R")
#source("treePlotter.R") #This is outdated now that identifyBindingGroup is in parser.R. treePlotter is only needed by app.R I think
#source("parser.R") #getNodeRole is from here, but app.R should source everything fine. If testing in isolation, source this.

# ==============================================================================
# findReducibleNodes
# Walks the AST and returns a list of all Binding_Group nodes that have
# exactly three children where the first child is a bindingTerm.
# Each entry is a list: $node (the Binding_Group) and $path (integer vector
# of child indices from the root to this node, for locating it in a clone).
# ==============================================================================
findReducibleNodes <- function(node, path = integer(0)) {
  results  <- list()
  children <- as.list(node$children)
  
  if (node$name == "Binding_Group" &&
      length(children) == 3 &&
      getNodeRole(children[[1]]$name) == "bindingTerm") {
    results <- c(results, list(list(node = node, path = path)))
  }
  
  for (i in seq_along(children)) {
    deeper  <- findReducibleNodes(children[[i]], c(path, i))
    results <- c(results, deeper)
  }
  
  results
}

# ==============================================================================
# nodeAtPath
# Given a root node and an integer path vector, walks the tree and returns
# the node at that path. Used to locate the same logical node in a Clone().
# ==============================================================================
nodeAtPath <- function(root, path) {
  node <- root
  for (i in path) {
    node <- as.list(node$children)[[i]]
  }
  node
}

# ==============================================================================
# freshName
# Returns a version of `name` that does not appear in `usedNames`.
# Increments the numeric suffix until a fresh name is found.
# ==============================================================================
freshName <- function(name, usedNames) {
  candidate <- incrementName(name)
  while (candidate %in% usedNames) {
    candidate <- incrementName(candidate)
  }
  candidate
}

# ==============================================================================
# collectNames
# Returns a character vector of all node names in the tree.
# Used to find all names currently in use before renaming.
# ==============================================================================
collectNames <- function(node) {
  c(node$name,
    unlist(lapply(as.list(node$children), collectNames)))
}

# ==============================================================================
# substituteName
# Walks `node` in place, replacing all free occurrences of `varName`
# with `replacementNode` (a Clone() is inserted at each occurrence).
#
# `boundVars` tracks variable names bound in the current scope so we
# do not substitute inside a re-binding of the same name.
#
# Alpha renaming: if `replacementNode` contains a free variable `y` and
# the current node binds `y`, we rename the bound `y` to a fresh name
# before substituting, preventing variable capture.
# ==============================================================================
substituteName <- function(node, varName, replacementNode,
                           boundVars = character(0)) {
  children <- as.list(node$children)
  
  if (node$name == "Binding_Group" && length(children) == 3) {
    bindingToken <- children[[1]]$name
    boundVar     <- substr(bindingToken, 2, nchar(bindingToken))
    
    # If this binding re-binds varName, stop substituting in this branch
    if (boundVar == varName) return(invisible(NULL))
    
    # Check for variable capture: if replacementNode contains boundVar as
    # a free variable, rename boundVar to something fresh before recursing
    freeInReplacement <- freeVariables(replacementNode)
    if (boundVar %in% freeInReplacement) {
      allNames  <- collectNames(node)
      fresh     <- freshName(boundVar, allNames)
      renameBoundVar(node, boundVar, fresh)
      # Re-read children after renaming
      children  <- as.list(node$children)
      bindingToken <- children[[1]]$name
      boundVar     <- substr(bindingToken, 2, nchar(bindingToken))
    }
    
    substituteName(node$children[[2]], varName, replacementNode,
                   c(boundVars, boundVar))
    
  } else {
    for (i in seq_along(children)) {
      child <- children[[i]]
      if (getNodeRole(child$name) == "term" &&
          child$name == varName &&
          !varName %in% boundVars) {
        # Replace this child with a clone of the replacement
        node$children[[i]] <- Clone(replacementNode)
      } else {
        substituteName(child, varName, replacementNode, boundVars)
      }
    }
  }
  
  invisible(NULL)
}

# ==============================================================================
# freeVariables
# Returns a character vector of all free variable names in the tree.
# A variable is free if it is not bound by any enclosing Binding_Group.
# ==============================================================================
freeVariables <- function(node, boundVars = character(0)) {
  children <- as.list(node$children)
  
  if (node$name == "Binding_Group" && length(children) == 3) {
    bindingToken <- children[[1]]$name
    boundVar     <- substr(bindingToken, 2, nchar(bindingToken))
    newBound     <- c(boundVars, boundVar)
    c(freeVariables(children[[2]], newBound),
      freeVariables(children[[3]], boundVars)) #newly bound variables don't bind the inputs, otherwise free variables could be recursively falsely bound
    
  } else if (getNodeRole(node$name) == "term") {
    if (!node$name %in% boundVars) node$name else character(0)
    
  } else {
    unlist(lapply(children, freeVariables, boundVars = boundVars))
  }
}

# ==============================================================================
# renameBoundVar
# Renames all occurrences of a bound variable `oldName` to `newName`
# within `node`, including the binding term itself.
# ==============================================================================
renameBoundVar <- function(node, oldName, newName) {
  children <- as.list(node$children)
  
  if (node$name == "Binding_Group" && length(children) == 3) {
    bindingToken <- children[[1]]$name
    boundVar     <- substr(bindingToken, 2, nchar(bindingToken))
    prefix       <- substr(bindingToken, 1, 1)
    
    if (boundVar == oldName) {
      node$children[[1]]$name <- paste0(prefix, newName)
      # Rename all occurrences in body only (not input, which is outer scope)
      renameTermInPlace(node$children[[2]], oldName, newName)
    } else {
      for (child in as.list(node$children)) {
        renameBoundVar(child, oldName, newName)
      }
    }
  } else {
    for (child in as.list(node$children)) {
      renameBoundVar(child, oldName, newName)
    }
  }
}

# ==============================================================================
# renameTermInPlace
# Renames all term nodes named `oldName` to `newName` within `node`,
# stopping at any Binding_Group that re-binds `oldName`.
# ==============================================================================
renameTermInPlace <- function(node, oldName, newName) {
  if (getNodeRole(node$name) == "term" && node$name == oldName) {
    node$name <- newName
    return(invisible(NULL))
  }
  children <- as.list(node$children)
  
  for (i in seq_along(children)) {
    child <- children[[i]]
    if (child$name == "Binding_Group") { #if your child is a binding group, get the bound variable name from your grandchild binding term
      innerChildren <- as.list(child$children)
      if (length(innerChildren) == 3) {
        innerVar <- substr(innerChildren[[1]]$name, 2,
                           nchar(innerChildren[[1]]$name))
        if (innerVar == oldName){
          renameTermInPlace(as.list(child$children)[[3]], oldName, newName)
          next  # re-bound, stop here...?
        } 
      }
    }
    renameTermInPlace(child, oldName, newName)
  }
}

# ==============================================================================
# betaReduce
# Performs one beta reduction on the Binding_Group at `path` in a Clone()
# of `ast`. Returns the new AST.
#
# Reduction: (\x . body) input  =>  body[x := input]
# The Binding_Group is replaced in its parent by the substituted body.
# If the Binding_Group is the root, the substituted body becomes the new root.
# ==============================================================================
betaReduce <- function(ast, path) {
  newAST   <- Clone(ast)
  target   <- nodeAtPath(newAST, path)
  children <- as.list(target$children)
  
  bindingToken <- children[[1]]$name
  varName      <- substr(bindingToken, 2, nchar(bindingToken))
  body         <- Clone(children[[2]])
  input        <- Clone(children[[3]])
  
  # Substitute input for varName throughout body
  # If the body is itself a single variable matching varName, substituteName
  # cannot replace it, since substituteName only replaces a node's children,
  # never the node it was directly called on. This case is handled here instead.
  if (getNodeRole(body$name) == "term" && body$name == varName) {
    body <- input
  } else {
    substituteName(body, varName, input)
  }
  
  # Replace the Binding_Group with the reduced body in its parent
  if (length(path) == 0) {
    # The Binding_Group is the root — body becomes the new root
    return(body)
  }
  
  parentPath   <- path[-length(path)]
  childIndex   <- path[length(path)]
  parentNode   <- nodeAtPath(newAST, parentPath)
  parentNode$children[[childIndex]] <- body
  
  newAST
}

# ==============================================================================
# reconstructExpression
# Walks an AST and reconstructs a text string of the expression.
# Binding terms get a period appended (e.g. \x.).
# Paren_Group / Binding_Group children are wrapped in parentheses.
# Tokens are separated by spaces.
# ==============================================================================
reconstructExpression <- function(node) {
  name     <- node$name
  children <- as.list(node$children)
  
  if (length(children) == 0) {
    # Leaf node
    if (getNodeRole(name) == "bindingTerm") {
      return(paste0(name, "."))
    }
    return(name)
  }
  
  parts <- lapply(children, reconstructExpression)
  inner <- paste(parts, collapse = " ")
  
  if (name == "Paren_Group") { #this is where I might add code to add more parentheses for clarity on some non-paren-groups
    return(paste0("(", inner, ")"))
  }
  
  #Binding_Group and Root default through
  inner
}

# ==============================================================================
# buildHyperGraph
# Entry point for the interpreter. Builds the full hyper-graph of ASTs
# reachable by beta reduction from the initial AST.
#
# Returns a list of records (see file header for record structure).
# ==============================================================================
buildHyperGraph <- function(ast, maxDepth = 20) {
  # Each record in the graph
  makeRecord <- function(id, ast, parents, depth) {
    list(id       = id,
         ast      = ast,
         parents  = parents,
         children = integer(0),
         status   = "normal",
         depth    = depth)
  }
  
  counter  <- new.env(parent = emptyenv())
  counter$n <- 0L
  
  freshId <- function() {
    counter$n <- counter$n + 1L
    counter$n
  }
  
  graph    <- list()
  queue    <- list()  # list of list(id, ast, depth)
  
  rootId   <- freshId()
  rootRec  <- makeRecord(rootId, ast, integer(0), 0L)
  graph[[as.character(rootId)]] <- rootRec
  queue    <- c(queue, list(list(id = rootId, ast = ast, depth = 0L)))
  
  while (length(queue) > 0) {
    # Pop front of queue
    current  <- queue[[1]]
    queue    <- queue[-1]
    curId    <- current$id
    curAst   <- current$ast
    curDepth <- current$depth
    
    reducible <- findReducibleNodes(curAst)
    
    if (length(reducible) == 0) next  # leaf node, no reductions possible
    
    for (reduction in reducible) {
      newAst <- betaReduce(curAst, reduction$path)
      newAst <- identifyBindingGroups(newAst)
      
      # Check if this AST is already in the graph (loop/convergence)
      existingId <- NULL
      for (rec in graph) {
        if (astEqual(rec$ast, newAst)) {
          existingId <- rec$id
          break
        }
      }
      
      if (!is.null(existingId)) {
        # Already seen — mark as loop, add edge only
        graph[[as.character(curId)]]$children <-
          c(graph[[as.character(curId)]]$children, existingId)
        graph[[as.character(existingId)]]$parents <-
          c(graph[[as.character(existingId)]]$parents, curId)
        graph[[as.character(existingId)]]$status <- "loop"
        next
      }
      
      newId  <- freshId()
      newRec <- makeRecord(newId, newAst, c(curId), curDepth + 1L)
      
      if (curDepth + 1L >= maxDepth) {
        newRec$status <- "maxDepth"
      }
      
      graph[[as.character(newId)]] <- newRec
      graph[[as.character(curId)]]$children <-
        c(graph[[as.character(curId)]]$children, newId)
      
      # Only enqueue if not at maxDepth
      if (newRec$status != "maxDepth") {
        queue <- c(queue, list(list(id = newId, ast = newAst,
                                    depth = curDepth + 1L)))
      }
    }
  }
  
  # --- Mark recursing chains ---
  # Find all maxDepth nodes and trace upward until a branching ancestor
  graph <- markRecursingChains(graph)
  
  graph
}

# ==============================================================================
# markRecursingChains
# For each maxDepth node, traces parent links upward until reaching a node
# with more than one child. Everything between the maxDepth node and that
# branching ancestor (exclusive) is marked "recursing".
# ==============================================================================
markRecursingChains <- function(graph) {
  for (rec in graph) {
    if (rec$status == "maxDepth") {
      currentId <- rec$id
      
      repeat {
        parents <- graph[[as.character(currentId)]]$parents
        if (length(parents) == 0) break  # reached root
        
        parentId  <- parents[[1]]
        parentRec <- graph[[as.character(parentId)]]
        
        if (length(parentRec$children) > 1) break  # branching node found
        
        # Mark this node as recursing if it isn't the direct child of
        # the branching node (i.e. it has only one parent and one child)
        if (graph[[as.character(currentId)]]$status != "maxDepth") {
          graph[[as.character(currentId)]]$status <- "recursing"
        }
        
        currentId <- parentId
      }
    }
  }
  
  graph
}
#Notes:
#path is an integer vector of child indices from the root to a given node. nodeAtPath replays those indices to find the same logical node in a cloned tree. This is necessary because Clone() produces new node objects, so you can't use the original node reference to locate a node in the clone.
#substituteName works by modifying the parent's children[[i]] slot rather than the node itself, because in data.tree you can't replace a node by modifying it from within — you have to reach it from its parent.
#The queue in buildHyperGraph is a breadth-first traversal, which means shallower ASTs are always processed before deeper ones, making the depth tracking straightforward.

debugReduce <- function(exprString) {
  tokens <- LexerTokenize(exprString)
  ast    <- parse_lambda(tokens)
  ast    <- identifyBindingGroups(ast)
  
  cat("=== Initial AST ===\n")
  viewAST(ast)
  
  reducible <- findReducibleNodes(ast)
  cat("\n=== Reducible nodes found:", length(reducible), "===\n")
  
  for (i in seq_along(reducible)) {
    cat("\nReduction", i, "- path:", reducible[[i]]$path, "\n")
    result <- tryCatch(
      betaReduce(ast, reducible[[i]]$path),
      error = function(e) {
        cat("  ERROR:", e$message, "\n")
        NULL
      }
    )
    if (!is.null(result)) {
      cat("  Result:\n")
      viewAST(result)
    }
  }
}

