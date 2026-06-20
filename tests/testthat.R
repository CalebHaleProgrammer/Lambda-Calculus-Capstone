library(testthat)

# Source all program files before running tests.
# setwd or here::here() may be needed depending on your project root;
# this assumes tests are run from the project root directory.
source("lexer.R")
source("parser.R")
source("treePlotter.R")
source("alphaEquivalence.R")
source("interpreter.R")

test_dir("tests/testthat")

#Notes from AI:
#The very first test, findReducibleNodes finds a single binding triple, will likely fail or behave oddly because the Root itself becomes the Binding_Group — findReducibleNodes walks from node and checks node$name == "Binding_Group", so it should still find it whether it's root or nested, but worth confirming.
#betaReduce(ast, integer(0)) reduces when the target is the root itself — confirm this matches how path = integer(0) is handled in your betaReduce.
#I expect several of these to fail on first run given everything we've found so far — that's the point. Run them and paste the full output here, and we'll work through failures one by one with much faster turnaround than debugging through the Shiny UI.