library(testthat)
source("lexer.R")

testLexer<-function(input="") {
test_that("custom input test",LexerTokenize(input))
test_that("basic test",{
  expect_equal(LexerTokenize("hello world"),c("hello","world"))
  })
test_that("can't bind symbol test",{
  expect_error(LexerTokenize("\("))
})


#expect_equal()
#expect_error()