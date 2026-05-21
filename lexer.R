library(foreach)

# TRUE if non-symbol (letter/digit/etc.), FALSE for ()./\
IsChar <- function(ch) {
  nchar(ch) > 0 && !ch %in% c("(", ")", ".", "/", "\\", " ")
}

PrimeNewTokenRead <- function(runningRead, fullExpression) { # Sets the first char of fullExpression to runningRead, taking first char
  list(
    runningRead = substr(fullExpression, 1, 1),
    fullExpression = substr(fullExpression, 2, nchar(fullExpression))
  )
}

ReadLetter <- function(runningRead, fullExpression) { # Moves the first char of fullExpression to runningRead
  if (fullExpression != "") {
    list(
      runningRead = paste0(runningRead, substr(fullExpression, 1, 1)),
    fullExpression = substr(fullExpression, 2, nchar(fullExpression))
    )
  }else{
    list(runningRead = runningRead, fullExpression = fullExpression)
  }
}

lastChar<-function(runningRead){substr(runningRead, nchar(runningRead), nchar(runningRead))}
firstChar<-function(fullExpression){substr(fullExpression, 1, 1)}

# ── Main tokenizing loop ──────────────────────────────────────────────────────
LexerTokenize <- function(inputText){
fullExpression<-inputText
runningRead<-""
tokens <- c()
#Sets both variables together, state remembers the name of the variables in the pair
state <- PrimeNewTokenRead(runningRead, fullExpression)
runningRead <- state$runningRead
fullExpression <- state$fullExpression

processed <- FALSE
#browser()
while (!processed) {
  #AI recommended this, probably for readability. Also removes redundant calls for data that isn't changing throughout most of the loop.
  #last character read and first character being read.
  lc <- lastChar(runningRead)
  fc <- firstChar(fullExpression)
  
  cat(sprintf("[Reading] runningRead: %-12s | firstChar: %-4s | tokens so far: [%s]\n",
              paste0("'", runningRead, "'"),
              paste0("'", fc,   "'"),
              paste(tokens, collapse = ", ")
  )) #paste0 and sprintf are used to create strings but not print them, then cat concatenates and prints to the console.
  
  
  #\ then non-char: Syntax error "Binding an invalid term after lambda"
  #non-char then . : Syntax error "Binding an invalid term before period"
  #. then ) : Syntax error : Syntax error "Invalid parenthesis around binding term"
  #char or lambda then char : Read
  #else: set token
  if (lc %in% c("\\","/") && !IsChar(fc)){
    stop("Syntax Error: Binding an invalid term after lambda; ",fc)
  }else if (!IsChar(lc) && fc=="."){
    stop("Syntax Error: Binding an invalid term before period; ",lc)
  }else if (lc=="."&&fc==")"){
    stop("Syntax Error: Invalid parenthesis around binding term.")
  }else if ((IsChar(lc)||lc%in% c("\\","/")) &&
            (IsChar(fc))){
    state          <- ReadLetter(runningRead, fullExpression)
    runningRead    <- state$runningRead
    fullExpression <- state$fullExpression
  }else{
    #set token, discard if a space
    if (runningRead!=" "){
      tokens <- c(tokens, runningRead)
    }
    if (fullExpression != "") {
      state          <- PrimeNewTokenRead(runningRead, fullExpression)
      runningRead    <- state$runningRead
      fullExpression <- state$fullExpression
    } else {
      processed <- TRUE
    }
  }
  
}

cat("\nFinal tokens:", paste(tokens, collapse = " , "), "\n")
tokens
}