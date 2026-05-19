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


library(data.tree)

# ==============================================================================
# isBindingToken
# Returns TRUE if the token begins with \ or /, marking a lambda binder.
# Uses substr rather than a regex since we only need the first character.
# ==============================================================================
isBindingToken <- function(token) {
  substr(token, 1, 1) %in% c("\\", "/")
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
  
  paren_node <- Node$new("Group_Paren")
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
  
  if (bind_idx + 2 > n) {
    stop("Application Parse Error: binding term must be followed by two terms")
  }
  
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
    
    for (i in seq(length(children), 1)) {
      if (isBindingToken(children[[i]]$name)) {
        parseBinding(node, i)
        found_binding <- TRUE
        break  # restart scan against the updated children list
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
  reduceParentheses(node)
  reduceBindings(node)
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
# viewAST
# Prints the AST to the console with indentation showing tree depth.
# ==============================================================================
viewAST <- function(node, depth = 0) {
  cat(strrep("  ", depth), node$name, "\n", sep = "")
  for (child in as.list(node$children)) {
    viewAST(child, depth + 1)
  }
}



parse_lambda(tokens)
