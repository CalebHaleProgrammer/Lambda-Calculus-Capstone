#install.packages("foreach")
library(foreach)


if(interactive()) 
{fullExpression <- readline(prompt="Enter your expression: ")}

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

cat("\nFinal tokens:", paste(tokens, collapse = " | "), "\n")

# ── Main Parsing loop ──────────────────────────────────────────────────────



