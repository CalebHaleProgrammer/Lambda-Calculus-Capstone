install.packages("foreach")
library(foreach)


if(interactive()) 
{fullExpression <- readline(prompt="Enter your expression: ")}
#test123

# TRUE if non-symbol (letter/digit/etc.), FALSE for ()./\
IsChar <- function(ch) {
  nchar(ch) > 0 && !ch %in% c("(", ")", ".", "/", "\\", " ")
} #nchar(ch) > 0 makes sure the argument isn't empty

# Sets the first char of fullExpression to runningRead, taking first char
PrimeNewTokenRead <- function() {
  runningRead    <<- substr(fullExpression, 1, 1)
  fullExpression <<- substr(fullExpression, 2, nchar(fullExpression))
}

# Moves the first char of fullExpression to runningRead
ReadLetter <- function() {
  if (fullExpression != "") {
    runningRead    <<- paste0(runningRead, substr(fullExpression, 1, 1))
    fullExpression <<- substr(fullExpression, 2, nchar(fullExpression))
  }
}

# ── Main tokenising loop ──────────────────────────────────────────────────────

tokens <- c()
PrimeNewTokenRead()

processed <- FALSE
#browser()
while (!processed) {
  
  # Peek at boundary characters
  lastChar  <- substr(runningRead,    nchar(runningRead),    nchar(runningRead))
  firstChar <- substr(fullExpression, 1, 1)   # "" when fullExpression is empty
  
  cat(sprintf(
    "[Reading] runningRead: %-12s | firstChar: %-4s | tokens so far: [%s]\n",
    paste0("'", runningRead, "'"),
    paste0("'", firstChar,   "'"),
    paste(tokens, collapse = ", ")
  )) #paste0 and sprintf are used to create strings but not print them, then cat concatenates and prints to the console.
  
  if (lastChar %in% c("(", ")", ".", " ") ||
      (IsChar(lastChar) && !IsChar(firstChar))) {
    # ── Token boundary reached: flush runningRead ──
    tokens <- c(tokens, runningRead)
    if (fullExpression != "") {
      PrimeNewTokenRead()
    } else {
      processed <- TRUE
    }
    
  } else if (IsChar(firstChar)) {
    # ── Still inside a multi-char token: keep reading ──
    ReadLetter()
    
  } else {
    stop("Parse error: may be trying to bind a syntax symbol ('",
         firstChar, "').")
  }
}

cat("\nFinal tokens:", paste(tokens, collapse = " | "), "\n")

