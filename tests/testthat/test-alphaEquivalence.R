test_that("identical expressions are alpha-equivalent", {
  a1 <- parse_lambda(c("\\x", ".", "x", "y"))
  a2 <- parse_lambda(c("\\x", ".", "x", "y"))
  expect_true(astEqual(a1, a2))
})

test_that("different bound variable names are still equivalent", {
  a1 <- parse_lambda(c("\\x", ".", "x", "y"))
  a2 <- parse_lambda(c("\\z", ".", "z", "y"))
  expect_true(astEqual(a1, a2))
})

test_that("different free variable names are NOT equivalent", {
  a1 <- parse_lambda(c("\\x", ".", "x", "y"))
  a2 <- parse_lambda(c("\\x", ".", "x", "w"))
  expect_false(astEqual(a1, a2))
})

test_that("different structure is not equivalent", {
  a1 <- parse_lambda(c("\\x", ".", "x", "y"))
  a2 <- parse_lambda(c("\\x", ".", "y", "x"))
  expect_false(astEqual(a1, a2))
})

test_that("incrementName appends 1 to a plain name", {
  expect_equal(incrementName("x"), "x1")
})

test_that("incrementName increments an existing numeric suffix", {
  expect_equal(incrementName("x1"), "x2")
  expect_equal(incrementName("y19"), "y20")
  expect_equal(incrementName("x264"), "x265")
})