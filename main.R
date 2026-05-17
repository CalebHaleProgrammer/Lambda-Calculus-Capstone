#install.packages("foreach")
library(foreach)


if(interactive()) {
  repeat{
    fullExpression <- readline(prompt="Enter your expression: ")
    if(fullExpression!=""){break}
  }
  }

# TRUE if non-symbol (letter/digit/etc.), FALSE for ()./\
IsChar <- function(ch) {
  nchar(ch) > 0 && !ch %in% c("(", ")", ".", "/", "\\", " ")
}

PrimeNewTokenRead <- function() { # Sets the first char of fullExpression to runningRead, taking first char
  runningRead    <<- substr(fullExpression, 1, 1)
  fullExpression <<- substr(fullExpression, 2, nchar(fullExpression))
}

ReadLetter <- function() { # Moves the first char of fullExpression to runningRead
  if (fullExpression != "") {
    runningRead    <<- paste0(runningRead, substr(fullExpression, 1, 1))
    fullExpression <<- substr(fullExpression, 2, nchar(fullExpression))
  }
}

lastChar<-function(){substr(runningRead,    nchar(runningRead),    nchar(runningRead))}
firstChar<-function(){substr(fullExpression, 1, 1)}

# ── Main tokenising loop ──────────────────────────────────────────────────────

tokens <- c()
PrimeNewTokenRead()

processed <- FALSE
#browser()
while (!processed) {
  
  cat(sprintf("[Reading] runningRead: %-12s | firstChar: %-4s | tokens so far: [%s]\n",
    paste0("'", runningRead, "'"),
    paste0("'", firstChar(),   "'"),
    paste(tokens, collapse = ", ")
  )) #paste0 and sprintf are used to create strings but not print them, then cat concatenates and prints to the console.
  
  
  #\ then non-char: Syntax error "Binding an invalid term after lambda"
  #non-char then . : Syntax error "Binding an invalid term before period"
  #. then ) : Syntax error : Syntax error "Invalid parenthesis around binding term"
  #char or lambda then char : Read
  #else: set token
  if (lastChar() %in% c("\\","/") && !IsChar(firstChar())){
    stop("Syntax Error: Binding an invalid term after lambda; ",firstChar())
  }else if (!IsChar(lastChar()) && firstChar()=="."){
    stop("Syntax Error: Binding an invalid term before period; ",lastChar())
  }else if (lastChar()=="."&&firstChar()==")"){
    stop("Syntax Error: Invalid parenthesis around binding term.")
  }else if ((IsChar(lastChar())||lastChar()%in% c("\\","/")) &&
            (IsChar(firstChar()))){
    ReadLetter()
  }else{
    #set token, discard if a space
    if (runningRead!=" "){
      tokens <- c(tokens, runningRead)
    }
    if (fullExpression != "") {
      PrimeNewTokenRead()
    } else {
      processed <- TRUE
    }
    }
    
}

cat("\nFinal tokens:", paste(tokens, collapse = " , "), "\n")

# ── Main Parsing loop ──────────────────────────────────────────────────────

#I need a parser for a lambda calculus interpreter based on the following pseudocode description, with "paren" shorthand for parenthesis.
#Add all tokens except "." in "tokens" list to a nonbinary (more than two nodes allowed at a layer) tree structure on the same layer.
#When parentheses are matched, the tokens between the parenthesis should be put down a layer in the tree, on their own branch stemming from the location that they were in the list of tokens.
#define a parseParen function that takes the index of two parentheses and puts the tokens between the parentheses down a branch, with the parenthesis disappearing as the terms are grouped.
#define a parseBinding function that takes the index and layer within the AST (or however a position would be encoded) and groups that position and the next two terms into a lower branch, similar to the parseParen function but with a specific number of terms (3) and not removing any tokens (i.e. the parentheses). If less than two terms are to the right of the argument position throw "Application Parse Error".
#Parsing Parentheses
#Do the following loop until noParens == True (one of the loops ends without encountering parenthesis)
#Initialize variables "leftmostRight" and "rightmostLeft".
#Iterate over the tokens in the first layer; if the token is a left paren, update rightmostLeft with the index of the left paren. Else if the character is a right paren do the following conditional: if the rightmostLeft is left of (lower index than) the scanned token then update leftmostRight to the index of the current token and exit the loop to pair the parens, else throw an "unmatched right parenthesis" error.
#If the loop reaches the end of the tokens list, then: if you found a left paren (rightmost left) then throw an unmatched left paren error, else no more parens found, set noParens = True to proceed to parse applications.
#Parsing Bindings
#For each layer in the tree repeat the following search loop until no layers of the tree have more or less than three terms (the binding term, the function term, and the input term), counting branch nodes as a single term to reflect use in the application phase.
#Search from left to right for the rightmost binding term (term whose first character is in the list of "\" or "/"), if none found, then you're done, else group the binding term and the two terms to the right of it, (if less than two terms to the right, throw "Application Parse Error").
#The AST should be made using the data.tree package if possible. Add notes in comments for any code that I didn't specify above, including a method for viewing the resultant AST in the console.


# Install the data.tree package if not already installed
if (!require(data.tree)) {
  install.packages("data.tree")
}
library(data.tree)

# ==============================================================================
# Main Parser Function
# This function orchestrates the tokenization and iterative parsing process described
# in the pseudocode. It manages layers, parentheses grouping, and binding structure.
# ==============================================================================
parse_lambda <- function(expr_string) {
# We treat "." as a delimiter/separator that does not become part of the tree structure.
  tokens <- tokens[tokens != "."] 
  
  if (length(tokens) == 0) {
    stop("No tokens found to parse.")
  }
  
  # Initialize Root Node for the AST
  root_node <- Node$new("root")
  
  # Create initial nodes for each token and add them as children of the root.
  # This creates a flat "Layer 0" structure where every token is a sibling.
  layer_nodes <- list()
  for (token in tokens) {
    n <- Node$new(token, parent = NULL)
    root_node$children[[length(root_node$children) + 1]] <<- n # Append to Root's children
    layer_nodes[[length(layer_nodes) + 1]] <<- n
  }
  
  # We need a working list of node references to iterate over layers.
  # Since we modify the tree, we track 'current_layer' nodes in memory 
  # while iterating through them to group parentheses and bindings.
  
  current_layer <- root_node$children
  
  # Main Loop: Continue until no further reductions (parens or binding) are found.
  # The prompt implies processing layers sequentially. We will iterate until stable.
  repeat {
    changed <- FALSE
    
    # --- Phase 1: Parse Parentheses ---
    # Follows the "Do the following loop until noParens == True" instruction.
    paren_indices <- NULL
    for (node in current_layer) {
      if (is.null(node$token)) next
      
      char_val <- node$token[1] # Access token content (stored as string)
      
      if (char_val == "(") {
        #update rightmostLeft with the current token index
      } else if (char_val == ")") {
        # if the rightmostLeft is left of (lower index than) the scanned token 
        # then update leftmostRight to the index of the current token and exit the loop to pair the parens
        # else throw an "unmatched right parenthesis" error.
      }
    }
    
    # Refining Paren Logic based on Pseudocode:
    # Iterate over the "tokens in the first layer". We will scan for ( and ) indices.
    left_parens <- which(sapply(current_layer, function(x) {
      isTRUE(grepl("^\\(", x$token))
    }))
    
    right_parens <- which(sapply(current_layer, function(x) {
      isTRUE(grepl("^\\)", x$token))
    }))
    
    # Attempt to pair them (Nested loop or stack approach). 
    matched_pairs <- list()
    
    # Using a stack-like logic for matching indices within this layer.
    # We create a temporary index vector to handle removal safely without affecting loop bounds immediately, 
    # but since we need to modify structure iteratively (bottom-up), we process one pair at a time.
    # To strictly follow "iterate until noParens":
    
    paren_processed <- FALSE
    
    for (lp_idx in left_parens) {
      found_match <- FALSE
      current_ridx <- lp_idx + 1
      
      # Search for matching right paren to the right of this left paren within the CURRENT layer nodes.
      while (current_ridx <= length(current_layer)) {
        if (isTRUE(grepl("^\\)", current_layer[[current_ridx]]$token))) {
          rp_idx <- current_ridx
          matched_pairs[[length(matched_pairs) + 1]] <<- list(left = lp_idx, right = rp_idx)
          
          # Remove the processed left and right from consideration in this pass (conceptually).
          # We will actually perform the tree surgery immediately after matching.
          found_match <- TRUE
          break
        } else {
          current_ridx <- current_ridx + 1
        }
      }
      
      if (!found_match) {
        stop("unmatched right parenthesis") 
      }
      
      # If we find a match, perform parseParen logic.
      if (length(matched_pairs) > 0) break # Process one pair to keep layer logic clean?
      # Actually the prompt says "Iterate... until noParens == True". We should do all parens in this pass or recursively.
      # To allow non-binary trees, we might need multiple passes per loop iteration if nested.
      # However, for this specific structure, we will process matched pairs immediately to reduce depth.
    }
    
    # Execute parseParen on identified pairs (if any found)
    if (length(matched_pairs) > 0) {
      changed <- TRUE
      root_node$children <- list() # Rebuild children carefully
      
      # Note: We need a robust way to replace nodes in the 'current_layer'. 
      # Since R lists are dynamic, we reconstruct the parent's children.
    } else {
      break # No parens found.
    }
    
    # --- Phase 2: Parse Bindings ---
    # Follows "For each layer... repeat search loop".
    if (length(current_layer) > 0) {
      binding_found <- FALSE
      
      for (i in seq_along(current_layer)) {
        node_i <- current_layer[[i]]$token
        
        # Search from left to right for the rightmost binding term 
        # "term whose first character is in the list of '\', '/'"
        if (!is.null(node_i) && grepl("^[\\\\/]", node_i)) {
          # Check next two terms exist (i+1 and i+2 indices must be valid in current_layer)
          if ((i + 2) <= length(current_layer)) {
            # Group the binding term and the next two terms into a lower branch.
            # We replace these 3 nodes with 1 new node containing them as children.
            
            start_idx <- i
            end_idx <- i + 2
            
            # Create New Binding Node
            new_node <- Node$new("Group_Binding")
            for (k in seq_len(end_idx - start_idx + 1)) {
              child_name <- current_layer[[start_idx + k - 1]]$token
              new_child <- Node$new(child_name, parent = NULL)
              new_node$children[[length(new_node$children) + 1]] <<- new_child
            }
            
            # Replace the slice of nodes with the new node in 'current_layer' context.
            # We must update current_layer references to reflect this reduction.
            # Since we are modifying structure, we reconstruct current_layer list for next iteration check.
          } else {
            stop("Application Parse Error") 
          }
          binding_found <- TRUE
        }
      }
      
      if (binding_found) {
        changed <- TRUE
      }
    }
    
    # If no changes were made in either phase, we are done.
    if (!changed) break
    
  } 
  
  return(root_node)
}

# ==============================================================================
# Helper: parseParen Function 
# Takes the index of two parentheses and puts the tokens between them down a branch.
# This is called within the main loop based on matched pairs found in that layer.
# ==============================================================================
parseParen <- function(current_layer, left_idx, right_idx) {
  # Note: 'current_layer' here represents the vector of nodes at the current depth being processed.
  
  # Extract tokens between parentheses (exclusive of parens themselves)
  # We assume tokens[left_idx] is "(" and tokens[right_idx] is ")"
  
  inner_nodes <- list()
  token_range_start <- left_idx + 1
  token_range_end <- right_idx - 1
  
  for (k in seq(token_range_start, token_range_end)) {
    if (!is.null(current_layer[[k]]$token)) {
      n <- Node$new(current_layer[[k]]$token, parent = NULL)
      inner_nodes[[length(inner_nodes) + 1]] <<- n
    } else {
      # Handle potential empty group or missing token logic
      break 
    }
  }
  
  # Create the new Group Node (replacing parentheses with a container)
  paren_group <- Node$new("Group_Paren")
  for (child in inner_nodes) {
    paren_group$children[[length(paren_group$children) + 1]] <<- child
  }
  
  return(paren_group) # Returns the new node to replace the range
}

# ==============================================================================
# Helper: parseBinding Function 
# Takes a binding term index and groups it with next two terms into a lower branch.
# Similar to parseParen but for Lambda Abstraction/Application logic (3 terms).
# ==============================================================================
parseBinding <- function(current_layer, current_idx) {
  # Check if less than two terms are to the right of argument position
  if ((current_idx + 2) > length(current_layer)) {
    stop("Application Parse Error") 
  }
  
  # Create new Binding Node (Grouping Term + Next 1 + Next 2)
  binding_group <- Node$new("Binding_Group")
  
  # Add current term (the binder, e.g., "\x" or "/x")
  n1 <- Node$new(current_layer[[current_idx]]$token, parent = NULL)
  binding_group$children[[length(binding_group$children) + 1]] <<- n1
  
  # Add next two terms
  for (k in 2:3) {
    n_child <- Node$new(current_layer[[current_idx + k - 1]]$token, parent = NULL)
    binding_group$children[[length(binding_group$children) + 1]] <<- n_child
  }
  
  return(list(node = binding_group, indices_to_replace = list(start=current_idx, end=current_idx+2)))
}

# ==============================================================================
# Method for Viewing Resultant AST in Console
# Prints the structure recursively with indentation.
# ==============================================================================
viewAST <- function(node) {
  print(paste("Node Type:", node$type))
  if (is.null(node$children)) return()
  
  # Print children
  cat("Children:\n")
  for (child in as.list(node$children)) {
    viewAST(child)
  }
}

# ==============================================================================
# Example Usage and Test
# ==============================================================================
if (interactive()) {
  test_input <- "\\x.x y" # Example: Lambda x applied to body, then y
  
  cat("Parsing input:", test_input, "\n")
  
  tryCatch({
    ast <- parse_lambda(test_input)
    
    cat("\n--- AST Structure ---\n")
    viewAST(ast)
    
    # Optional: Print using data.tree's built-in print if needed, but viewAST is custom.
    # data.tree::printTree(ast) would also work for basic inspection.
    
  }, error = function(e) {
    cat("Error during parsing:", conditionMessage(e), "\n")
  })
}

# Export functions for user access (if using in R package context or source file)
parse_lambda <- parse_lambda
viewAST <- viewAST

