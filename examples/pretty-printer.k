;;;
;;; pretty-printer.k
;;;
;;; A pretty printer. Adapted from Haskell source from
;;;
;;;   Philip Wadler: A prettier printer, 2003,
;;;     http://homepages.inf.ed.ac.uk/wadler/papers/prettier/prettier.pdf
;;;
;;; Try
;;;
;;;   >> (load "pretty-printer.k")
;;;   >> (pprint (with-input-from-file "pretty-printer.k" read))
;;;
;;; Does not print cyclic structures.
;;;

($provide! (pprint)

  ($provide! (pretty text line nil nest cat group)

    ;;
    ;; Lists are used in place of the original Haskell datatype constructors
    ;;
    ;;  Haskell                         Bronze Age Lisp
    ;;
    ;;  data DOC = NIL                  (nil)
    ;;           | DOC :<> DOC          (cat DOC1 DOC2)
    ;;           | NEST Int DOC         (nest INT DOC)
    ;;           | TEXT String          (text STRING)
    ;;           | LINE                 (line)
    ;;           | DOC :<|> DOC         (alt DOC1 DOC2)
    ;;
    ;; The operative $form constructs a list whose first element
    ;; is an unevaluated symbol.
    ;;

    ($define! $form
      ($vau (head-symbol . rest) denv
        (cons head-symbol (eval (cons list rest) denv))))

    ;;
    ;; constructors as applicatives
    ;;

    ($define! text ($lambda (x) ($form text x)))
    ($define! line ($form line))
    ($define! nil  ($form nil))
    ($define! nest ($lambda (i x) ($form nest i x)))

    ($define! cat
      ($lambda xs
        ($cond
          ((null? xs) nil)
          ((pair? xs) ($form cat (car xs) (apply cat (cdr xs)))))))

    ;;
    ;; Haskell function definition
    ;;
    ;;   f (ctor1 V11 V21 ...) X2 X3 ... = EXPR1
    ;;   f (ctor2 V21 V22 ...) X2 X3 ... = EXPR2
    ;;   ...
    ;;
    ;; is implemented by
    ;;
    ;;   ($force-dispatch (X2 X3 ...)
    ;;     ((ctor1 V11 V12 ...) EXPR1)
    ;;     ((ctor2 V21 V22 ...) EXPR2)
    ;;     ...)
    ;;
    ;; The operative $force-dispatch emulates Haskell's lazines and pattern
    ;; matching for the simple case used in this example.
    ;;

    ($define! $force-dispatch
      ($vau (extra-args . cases) denv
        ($define! case-handler
          ($lambda (((head-symbol . lhs-vars) rhs))
            (list head-symbol
                  (eval (list $lambda
                              (cons (cons #ignore lhs-vars) extra-args)
                              (list $lazy rhs))
                        denv))))
        ($define! handlers
          (apply (wrap $bindings->environment)
                (map case-handler cases)
                denv))
        ($lambda (x . args)
          (apply (eval (car (force x)) handlers)
                 (cons (force x) args)))))

    ;; The following is a simple-minded port of the Haskell code.

    ($define! pretty
      ($lambda (w x)
        (layout (force (best w 0 x)))))

    ($define! group
      ($lambda (x)
        ($form alt (flatten x) x)))

    ($define! flatten
      ($force-dispatch ()
        ((nil)      ($form nil))
        ((cat x y)  ($form cat (flatten x) (flatten y)))
        ((nest i x) ($form nest i (flatten x)))
        ((text s)   ($form text s))
        ((line)     ($form text " "))
        ((alt x y)  (flatten x))))

    ;;
    ;; Haskell                          Bronze Age Lisp (the cdr is lazy!)
    ;;
    ;; data Doc = Nil                   ()
    ;;     | String ‘Text‘ Doc          (STRING . Doc)
    ;;     | Int ‘Line‘ Doc             (INT . Doc)
    ;;

    ($define! layout
      ($lambda (z)
        ($cond
          ((null? z)
            #inert)
          ((string? (car z))
            (write-string (car z))
            (layout (force (cdr z))))
          ((integer? (car z))
            (newline)
            (write-string (make-string (car z) #\space))
            (layout (force (cdr z)))))))

    ($define! best
      ($lambda (w k x)
        (be w k (list (cons 0 x)))))

    ($define! be
      ($lambda (w k z)
        ($if (null? z)
          ()
          (be-head (cdar z) (caar z) w k (cdr z)))))

    ($define! be-head
      ($force-dispatch (i w k z)
        ((nil)      (be w k z))
        ((cat x y)  (be w k (list* (cons i x) (cons i y) z)))
        ((nest j x) (be w k (list* (cons (+ i j) x) z)))
        ((text s)   (cons s (be w (+ k (string-length s)) z)))
        ((line)     (cons i (be w i z)))
        ((alt x y)  (better w k (be w k (list* (cons i x) z))
                                (be w k (list* (cons i y) z))))))

    ($define! better
      ($lambda (w k x y)
        ($if (fits? (- w k) (force x)) x y)))

    ($define! fits?
      ($lambda (w x)
        ($cond
          ((<? w 0)           #f)
          ((null? x)          #t)
          ((string? (car x))  (fits? (- w (string-length (car x)))
                                    (force (cdr x))))
          (#t                 #t)))))

  ;;
  ;; Compute tree representation of arbitrary lisp object.
  ;;

  ($provide! (tree)

    ($define! tree
      ($lambda (x)
        ($cond
          ((pair? x)
            (group (cat (text "(")
                        (tree (car x))
                        (nest 2 (tail (cdr x)))
                        (text ")"))))
          ((vector? x)
            (group (cat (text "#(")
                        (tree (car x))
                        (nest 2 (tail (cdr x)))
                        (text ")"))))
          (#t
            (text ($let ((p (open-output-string)))
                    (write x p)
                    (get-output-string p)))))))

    ($define! tail
      ($lambda (xs)
        ($cond
          ((null? xs)  nil)
          ((pair? xs)  (cat line (tree (car xs)) (tail (cdr xs))))
          (#t          (cat line (text ". ") (tree xs)))))))

  ;;
  ;; public API
  ;;

  ($define! pprint
    ($lambda (x)
      (pretty 80 (tree x)))))
