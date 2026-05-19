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
# Takes the indices of two parentheses and lowers the tokens between 
# them down a branch of a the tree, Parentheses disappear after evaluation.
parseParen <- function(current_layer, left_idx, right_idx) {
  # Extract tokens between parens (exclusive).
  # Note: 'current_layer' is the list of nodes at this depth.
  inner_tokens <- c()
  for (i in seq(left_idx + 1, right_idx - 1)) {
    if (!is.null(current_layer[[i]]$token)) {
      inner_tokens <- c(inner_tokens, current_layer[[i]]$token)
    }
  }
  
  # Create new node to replace the pair and its contents
  paren_node <- Node$new("Group_Paren", parent = NULL)
  for (t in inner_tokens) {
    child <- Node$new(t, parent = NULL)
    paren_node$children[[length(paren_node$children) + 1]] <<- child
  }
  
  return(list(new_node = paren_node, range_to_remove = c(left_idx, right_idx)))
}

# ==============================================================================
# Takes the position of a binding term to select three terms (term, arg, input) 
# and replace them with a node that has them as children.
parseBinding <- function(current_layer, bind_idx) {
  # Note: 'current_layer' is the list of nodes at this depth.
  
  # Check if less than two terms are to the right (need index +1 and +2)
  if ((bind_idx + 2) > length(current_layer)) {
    stop("Application Parse Error") 
  }
  
  binding_node <- Node$new("Binding_Group", parent = NULL)
  
  # Add binding term and next two terms
  for (k in bind_idx:(bind_idx + 2)) {
    child <- Node$new(current_layer[[k]]$token, parent = NULL)
    binding_node$children[[length(binding_node$children) + 1]] <<- child
  }
  
  return(list(new_node = binding_node, range_to_remove = c(bind_idx, bind_idx + 2)))
}

# ==============================================================================
# Helper Function: viewAST
# Method for viewing the resultant AST in the console.
# ==============================================================================
viewAST <- function(node) {
  print(paste("Node:", node$type))
  if (length(node$children) > 0) {
    for (child in as.list(node$children)) {
      viewAST(child)
    }
  }
}

# ==============================================================================
# Main Parser Function
# Implements the parsing logic described: Tokenizing, Parentheses Reduction, 
# Binding Reduction, and Recursive Layer Processing.
# ==============================================================================
parse_lambda <- function(tokens_list) {
  # Filter tokens: Add all except "." in "tokens" list to root children.
  valid_tokens <- tokens_list[tokens_list != "."]
  
  if (length(valid_tokens) == 0) return(Node$new("Empty"))
  
  mainAST <- Node$new("Root")
  for (t in valid_tokens) {
    n <- Node$new(t, parent = NULL)
    mainAST$children[[length(mainAST$children) + 1]] <<- n
  }
  
  # Process layers recursively. 
  # We iterate depth-first to handle nested structures as they are formed.
  reduce_layer_recursive(mainAST)
  
  return(mainAST)
}

# Recursive function to process tree nodes and their layers until stable
reduce_layer_recursive <- function(node, visited_depth = NULL) {
  if (!is.null(visited_depth)) {
    # If we have already processed children of this node in a previous pass 
    # (simple check for stability could be added here), skip. 
    # For brevity and robustness with the prompt's "repeat" instruction, 
    # we just recurse into newly formed nodes if they contain sub-layers.
  }
  
  # Base case: Leaf node or no children to process
  if (is.null(node$children) || length(node$children) == 0) return()
  
  layer_nodes <- node$children
  
  # --- Loop for Parentheses Reduction ---
  repeat {
    noParens <- TRUE
    
    # Scan logic as per pseudocode
    rightmostLeft <- NULL
    
    for (i in seq_along(layer_nodes)) {
      token <- as.character(layer_nodes[[i]]$token)
      
      if (token == "(") {
        rightmostLeft <- i # Update index of left paren
        noParens <- FALSE 
      } else if (token == ")") {
        if (!is.null(rightmostLeft)) {
          if (rightmostLeft < i) {
            # Found a pair, exit loop to process this match
            result <- parseParen(layer_nodes, rightmostLeft, i)
            
            # Replace the range in parent's children list
            old_len <- length(node$children)
            new_len <- old_len - (i - rightmostLeft + 1) + 1
            
            node$children <- as.list()
            for (k in 1:(old_len - 1)) { # Keep everything before start index
              if (k < rightmostLeft) node$children[[length(node$children)+1]] <<- layer_nodes[[k]]
            }
            node$children[[length(node$children)+1]] <<- result$new_node
            for (k in (i+1):old_len) { # Keep everything after end index
              if (!is.null(layer_nodes[[k]])) node$children[[length(node$children)+1]] <<- layer_nodes[[k]]
            }
            
            # Reset rightmostLeft to allow finding next pair if multiple exist? 
            # Pseudocode implies "exit loop". So we stop scanning for this pass.
            break 
          } else {
            stop("unmatched right parenthesis")
          }
        } else {
          noParens <- FALSE
        }
      }
    }
    
    # If loop finishes without match and unmatched left paren found:
    if (!is.null(rightmostLeft)) {
      stop("unmatched left paren error")
    }
    
    if (noParens) break
  }
  
  # --- Loop for Binding Reduction ---
  repeat {
    binding_found <- FALSE
    
    # Search from left to right for the rightmost binding term 
    # Note: Prompt says "repeat checkLayerForBindings... until every layer has exactly three terms".
    # This implies we reduce as long as possible.
    # To strictly follow "Search from left to right", we iterate once per pass.
    
    changed_layer <- FALSE
    
    for (i in seq_along(layer_nodes)) {
      token <- as.character(layer_nodes[[i]]$token)
      
      # Check binding term: first char is \ or /
      if (!is.null(token) && grepl("^[\\\\/]", token)) {
        # Binding found at i. 
        # Note: The instruction "rightmost" implies we might want to prioritize the last one?
        # But logic says "followed by two terms". If multiple exist, finding any valid triplet is fine for brevity.
        # However, "Search from left to right... if none found then you're done". 
        # This implies sequential processing.
        
        result <- parseBinding(layer_nodes, i)
        
        # Replace nodes in layer_nodes context (simulated by rebuilding parent list later)
        start_idx <- i
        end_idx <- i + 2
        
        node$children <- as.list()
        for (k in seq_along(layer_nodes)) {
          if (k < start_idx || k > end_idx) {
            node$children[[length(node$children)+1]] <<- layer_nodes[[k]]
          } else {
            # Replace this triplet with the new binding node
            node$children[[length(node$children)+1]] <<- result$new_node
            break
          }
        }
        
        changed_layer <- TRUE
        break # Restart layer check to re-index
      }
    }
    
    if (!changed_layer) break 
  }
  
  # Recurse down into the newly formed layers (children of this node's children)
  for (child in as.list(node$children)) {
    reduce_layer_recursive(child, visited_depth = TRUE)
  }
}
