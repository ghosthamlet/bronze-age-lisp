;; basic test of =?, etc.
(list
  (list (<? 0 0) (<=? 0 0) (=? 0 0) (>=? 0 0) (>? 0 0))
  (list (<? 0 1) (<=? 0 1) (=? 0 1) (>=? 0 1) (>? 0 1))
  (list (char<? #\A #\A) (char<=? #\A #\A) (char=? #\A #\A) (char>=? #\A #\A) (char>? #\A #\A))
  (list (char<? #\A #\B) (char<=? #\A #\B) (char=? #\A #\B) (char>=? #\A #\B) (char>? #\A #\B))
  (list (string<? "a" "a") (string<=? "a" "a") (string=? "a" "a") (string>=? "a" "a") (string>? "a" "a"))
  (list (string<? "a" "b") (string<=? "a" "b") (string=? "a" "b") (string>=? "a" "b") (string>? "a" "b"))
  (list (string<? "a" "aa") (string<=? "a" "aa") (string=? "a" "aa") (string>=? "a" "aa") (string>? "a" "aa"))
  (list (string<? "" "b") (string<=? "" "b") (string=? "" "b") (string>=? "" "b") (string>? "" "b")))
