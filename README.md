# Lambda-Calculus-Capstone

Run app.R to create a shiny-powered UI for the interpreter program. This program and the research accompanying it was the capstone project for my Bachelor's Degree.

There is an entry box for a text expression that will be tokenized by the lexer, parsed into an AST (displayed on the right in the UI), then evaluated using interpreter.R. The Timeline Tracker document records my learning process, and some of my thinking process and design decisions. My notable syntax rules are:

-   you need spaces or symbols to separate tokens: "xyz" will be treated as one variable name.

-   optional periods used to break up bound variables and function bodies should be immediately after the bound variable: "\\x . a" will throw an error, "\\x. a" is appropriate.

-   parentheses can be used to break up terms in general, and the collective should be treated as a term: "\\x (a b x) c" will treat (a b x) as one term when it is identifying the function body that "\\x" applies to and that "c" would be substituted into.

-   "(\\x. x b) a" should be the same as "\\x. x b a", what I understand to be standard LC syntax should apply; left associativity for inputs, right associativity for bindings/function abstractions, working "outward" from the "middle". So, "\\x. \y. x y a b" should be "(\\x. (\y. x y) a) b".

The left tree shows possible evaluation paths. igraph and Data.tree were used for the AST structures, shiny, colourpicker, and visNetwork for the UI, and testthat for automatic case-testing.

Future development: UI could use some polishing, associativity might not be considered properly during evaluation, and the naming system to avoid variable capture seems buggy. (e.g. "\\name. (hello I'm name)" triggers a rename.)
