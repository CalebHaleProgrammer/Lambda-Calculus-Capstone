#install.packages("foreach")
#install.packages("igraph")
library(foreach)
#library(DiagrammeR)
#library(igraph)
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



if(interactive()) {
  repeat{
    fullExpression <- readline(prompt="Enter your expression: ")
    if(fullExpression!=""){break}
  }
  }

tokens<-LexerTokenize(fullExpression)

initAST<-parse_expression(tokens)
initAST <- identifyBindingGroups(initAST)

viewAST(initAST)
#plot(initAST)
plotAST(initAST)
#viewAST(parse_lambda(c("\\x", ".", "\\y", ".", "x", "y")))

viewAST(identifyBindingGroups(parse_expression(LexerTokenize("(/x. x) y"))))
