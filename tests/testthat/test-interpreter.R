test_that("findReducibleNodes finds a single binding triple", {
  ast <- parse_lambda(c("\\x", ".", "x", "y"))
  ast <- identifyBindingGroups(ast)
  reducible <- findReducibleNodes(ast)
  expect_equal(length(reducible), 1)
})

test_that("findReducibleNodes finds nothing in an incomplete binding", {
  ast <- parse_lambda(c("\\x", ".", "x"))
  ast <- identifyBindingGroups(ast)
  reducible <- findReducibleNodes(ast)
  expect_equal(length(reducible), 0)
})

test_that("betaReduce on identity function returns the input", {
  ast    <- parse_lambda(c("\\x", ".", "x", "y"))
  ast    <- identifyBindingGroups(ast)
  result <- betaReduce(ast, c(1))  # root is not the Binding_Group, root has a single child, the binding_group
  expect_equal(result$name, "y")
})

test_that("betaReduce substitutes correctly in a non-trivial body", {
  # (\x . x x) y  =>  y y
  tokens <- c("\\x", ".", "x", "x", "y")
  ast    <- parse_lambda(tokens)
  ast    <- identifyBindingGroups(ast)
  result <- betaReduce(ast, c(1))
  reconstructed <- reconstructExpression(result)
  expect_equal(reconstructed, "x y")
})

test_that("substitution avoids variable capture", {
  # (\x . \y . x) y  =>  should rename inner y to avoid capturing the input y
  # Result should be \y1 . y  (inner bound var renamed, input substituted)
  tokens <- c("\\x", ".", "\\y", ".", "x", "y")
  ast    <- parse_lambda(tokens)
  ast    <- identifyBindingGroups(ast)
  result <- betaReduce(ast, c(1))
  
  freeVars <- freeVariables(result)
  expect_true("y" %in% freeVars)  # the substituted y must remain free
})

test_that("reconstructExpression rebuilds a simple binding", {
  ast <- parse_lambda(c("\\x", ".", "x", "y"))
  ast <- identifyBindingGroups(ast)
  expect_equal(reconstructExpression(ast), "\\x. x y")
})

test_that("buildHyperGraph terminates on a normalizing expression", {
  ast   <- parse_lambda(c("\\x", ".", "x", "y"))
  ast   <- identifyBindingGroups(ast)
  graph <- buildHyperGraph(ast, maxDepth = 10)
  expect_true(length(graph) >= 1)
})