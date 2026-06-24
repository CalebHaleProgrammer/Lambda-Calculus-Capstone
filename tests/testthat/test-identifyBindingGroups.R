test_that("a complete binding triple is already a Binding_Group after parsing", {
  ast <- parse_lambda(c("\\x", ".", "x", "y"))
  ast <- identifyBindingGroups(ast)
  expect_equal(ast$name, "Root")
  expect_equal(ast$children[[1]]$name, "Binding_Group")
})

#keep an eye on these two!
test_that("a redundant Paren_Group wrapping a Binding_Group is collapsed", {
  ast <- parse_lambda(c("a", "(", "\\x", ".", "x", "y", ")"))
  ast <- identifyBindingGroups(ast)
  expect_equal(ast$children[[2]]$name, "Binding_Group")
})
test_that("a Paren_Group with an incomplete binding is relabeled directly", {
  ast <- parse_lambda(c("(", "\\x", ".", "a", ")"))
  ast <- identifyBindingGroups(ast)
  expect_equal(ast$children[[1]]$name, "Binding_Group")
  expect_equal(length(ast$children[[1]]$children), 2)
})

test_that("Paren_Group with only 2 children stays Paren_Group", {
  ast <- parse_lambda(c("(", "a", "b", ")"))
  ast <- identifyBindingGroups(ast)
  expect_equal(ast$children[[1]]$name, "Paren_Group")
})

test_that("identifyBindingGroups does not affect non-binding triples", {
  ast <- parse_lambda(c("(", "a", "b", "c", ")"))
  ast <- identifyBindingGroups(ast)
  # 3 children but first child is not a bindingTerm, should stay Paren_Group
  expect_equal(ast$children[[1]]$name, "Paren_Group")
})