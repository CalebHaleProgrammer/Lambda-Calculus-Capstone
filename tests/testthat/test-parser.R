#test_that("simple binding parses into a Binding_Group", {
#  ast <- parse_expression(c("\\x", ".", "x"))
#  expect_equal(ast$name, "Root")
#  expect_equal(length(ast$children), 1)
#  expect_equal(ast$children[[1]]$name, "Binding_Group")
#})

#This may change in the future if no-input functions are treated as a binding group
test_that("a binding with only a body and no input stays ungrouped", {
  ast <- parse_expression(c("\\x", ".", "x"))
  expect_equal(ast$name, "Root")
  expect_equal(length(ast$children), 2)
  expect_equal(ast$children[[1]]$name, "\\x")
  expect_equal(ast$children[[2]]$name, "x")
})

test_that("a binding with body and input forms a Binding_Group", {
  ast <- parse_expression(c("\\x", ".", "x", "y"))
  expect_equal(ast$name, "Root")
  expect_equal(length(ast$children), 1)
  expect_equal(ast$children[[1]]$name, "Binding_Group")
})

test_that("parentheses group their contents", {
  ast <- parse_expression(c("(", "a", "b", ")"))
  expect_equal(ast$children[[1]]$name, "Paren_Group")
  expect_equal(length(ast$children[[1]]$children), 2)
})

test_that("nested parentheses resolve inside-out", {
  tokens <- c("\\x", ".", "(", "a", "(", "b", "c", ")", ")")
  ast    <- parse_expression(tokens)
  # Should not throw, and should produce nested Paren_Group structure, need to finish this test!
  expect_equal(ast$name, "Root") 
})

test_that("a complete binding triple groups correctly", {
  ast <- parse_expression(c("\\x", ".", "x", "y"))
  bindingNode <- ast$children[[1]]
  expect_equal(bindingNode$name, "Binding_Group")
  expect_equal(length(bindingNode$children), 3)
  expect_equal(bindingNode$children[[1]]$name, "\\x")
  expect_equal(bindingNode$children[[2]]$name, "x")
  expect_equal(bindingNode$children[[3]]$name, "y")
})

test_that("unmatched parenthesis throws a parse error", {
  expect_error(parse_expression(c("(", "a")), "unmatched")
  expect_error(parse_expression(c("a", ")")), "unmatched")
})