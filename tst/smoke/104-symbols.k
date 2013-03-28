;; test basic symbol manipulation
(list
  (symbol? ((unwrap list) . ttt))
  (symbol? "vvv")
  (string->symbol "abcd")
  (symbol->string ((unwrap list) . xyz))
  (eq? (string->symbol "pqr") ((unwrap list) . pqr))
  (eq? ((unwrap list) . uvw) (string->symbol "pqr")))
