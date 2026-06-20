test_that("a complete binding triple is already a Binding_Group after parsing", {
  ast <- parse_lambda(c("\\x", ".", "x", "y"))
  ast <- identifyBindingGroups(ast)
  expect_equal(ast$name, "Root")
  expect_equal(ast$children[[1]]$name, "Binding_Group")
})

test_that("Paren_Group becomes Binding_Group when it has a binding triple", {
  ast <- parse_lambda(c("a", "(", "\\x", ".", "x", "y", ")"))
  ast <- identifyBindingGroups(ast)
  parenNode <- ast$children[[2]]
  expect_equal(parenNode$name, "Binding_Group")
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