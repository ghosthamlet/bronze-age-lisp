;; test basic functionality of eq? and equal?
(list
  (eq? 0 0) (eq? 0 1)
  (eq? (wrap unwrap) (wrap unwrap))
  (eq? (unwrap wrap) (unwrap wrap))
  (eq? (cons 0 1) (cons 0 1))
  (equal? (cons 0 1) (cons 0 1))
  (equal? (cons 0 1) (cons 0 2)))
