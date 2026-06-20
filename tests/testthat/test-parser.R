test_that("simple binding parses into a Binding_Group", {
  ast <- parse_lambda(c("\\x", ".", "x"))
  expect_equal(ast$name, "Root")
  expect_equal(length(ast$children), 1)
  expect_equal(ast$children[[1]]$name, "Binding_Group")
})

test_that("binding without two following terms is left unparsed", {
  ast <- parse_lambda(c("\\x", ".", "x"))
  # Only one token follows \x (the body), no third term for input —
  # so this should NOT become a complete Binding_Group requiring 3 children
  bindingNode <- ast$children[[1]]
  expect_equal(length(bindingNode$children), 2)
})

test_that("parentheses group their contents", {
  ast <- parse_lambda(c("(", "a", "b", ")"))
  expect_equal(ast$children[[1]]$name, "Paren_Group")
  expect_equal(length(ast$children[[1]]$children), 2)
})

test_that("nested parentheses resolve inside-out", {
  tokens <- c("\\x", ".", "(", "a", "(", "b", "c", ")", ")")
  ast    <- parse_lambda(tokens)
  # Should not throw, and should produce nested Paren_Group structure
  expect_equal(ast$name, "Root")
})

test_that("a complete binding triple groups correctly", {
  ast <- parse_lambda(c("\\x", ".", "x", "y"))
  bindingNode <- ast$children[[1]]
  expect_equal(bindingNode$name, "Binding_Group")
  expect_equal(length(bindingNode$children), 3)
  expect_equal(bindingNode$children[[1]]$name, "\\x")
  expect_equal(bindingNode$children[[2]]$name, "x")
  expect_equal(bindingNode$children[[3]]$name, "y")
})

test_that("unmatched parenthesis throws a parse error", {
  expect_error(parse_lambda(c("(", "a")), "unmatched")
  expect_error(parse_lambda(c("a", ")")), "unmatched")
})