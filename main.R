#install.packages("foreach")
#install.packages("igraph")
library(foreach)
#library(DiagrammeR)
library(igraph)
library(data.tree)
source("lexer.R")
source("parser.R")
source("treePlotter.R")
#source("treeConverter.R")

#source("file.R")   # loads everything defined in other files
#A Few Tips
#Path is relative to your working directory, not the file doing the sourcing. 
# In RStudio, your working directory is usually your project root (check with getwd()). 
#source() runs the whole file top to bottom, so avoid putting loose "script-style" code in helper files — keep them to function and variable definitions only.
#Order matters — if analysis.R uses functions from utils.R, source utils.R first.

# ==============================================================================
# viewAST   Prints the AST to the console with indentation showing tree depth.
# ==============================================================================
viewAST <- function(node, depth = 0) {
  cat(strrep("  ", depth), node$name, "\n", sep = "")
  for (child in as.list(node$children)) {
    viewAST(child, depth + 1)
  }
}

if(interactive()) {
  repeat{
    fullExpression <- readline(prompt="Enter your expression: ")
    if(fullExpression!=""){break}
  }
  }

tokens<-LexerTokenize(fullExpression)

initAST<-parse_lambda(tokens)

viewAST(initAST)
plot(initAST)
plotAST(initAST)

