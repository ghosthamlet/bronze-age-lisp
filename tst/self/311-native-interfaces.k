;;;
;;; 311-native-interfaces.k
;;;
;;; Test native code generator.
;;;

($define! $equal?
  ($vau xs denv
    ($define! ys
      (map ($lambda (x) (protect-eval x denv)) xs))
    ($if ($and? (apply equal? (cons "return" (map car ys)))
                (apply equal? (map cadr ys)))
      (pass)
      (fail-with-report "code-generator"
        xs ys (list (car xs) ($quote |...|))))))

;;
;; compile simple examples and call the resulting combiners
;;
($let ((f42 (make-compiled-operative #ignore #ignore
              ($quote (#:load (#:quote 42) (#:return))))))
  ($equal? 42 (f42) (f42 1) (f42 1 2)))

($let ((f3 (make-compiled-operative #ignore #ignore
             ($quote (#:load (#:standard (+ 1 2)) (#:return))))))
  ($equal? 3 (f3) (f3 1) (f3 1 2)))

($let ((f-arglist (make-compiled-operative 0 #ignore
                    ($quote (#:load 0 (#:return))))))
  ($equal? () (f-arglist))
  ($equal? ($quote* 1) (f-arglist 1))
  ($equal? ($quote* 1 2) (f-arglist 1 2)))

($let ((f-denv (make-compiled-operative #ignore 0
                  ($quote (#:load 0 (#:return))))))
  ($equal? (get-current-environment) (f-denv))
  ($equal? (get-current-environment) (f-denv 1 2)))

;;
;; primitives
;;

($let ((f-car (make-compiled-operative 0 #ignore
               ($quote (#:primitive #:car (0) (#:return))))))
  ($equal? 1 (f-car 1))
  ($equal? 2 (f-car 2 3)))

($let ((f-cdr (make-compiled-operative 0 #ignore
               ($quote (#:primitive #:cdr (0) (#:return))))))
  ($equal? () (f-cdr 1))
  ($equal? (list 3) (f-cdr 2 3)))

($let ((f-cons
         (make-compiled-operative 0 #ignore
           ($quote (#:primitive #:cons (0 (#:quote ())) (#:return))))))
  ($equal? (list (list 1)) (f-cons 1))
  ($equal? (list (list 2 3)) (f-cons 2 3)))

($let ((f-plus-10
         (make-compiled-operative 0 #ignore
           ($quote (#:primitive #:+ (0 (#:quote 10)) (#:return))))))
  ($equal? 10 (f-plus-10 . 0))
  ($equal? 0 (f-plus-10 . -10)))

($let ((f-nn1
         (make-compiled-operative 0 #ignore
           ($quote (#:primitive #:- (0 (#:quote 1))
                     (#:primitive #:* (0 #:acc)
                       (#:return)))))))
  ($equal? 0 (f-nn1 . 0))
  ($equal? 0 (f-nn1 . 1))
  ($equal? 2 (f-nn1 . 2))
  ($equal? 6 (f-nn1 . 3))
  ($equal? 12 (f-nn1 . 4)))

($let ((f-eval
         (make-compiled-operative 0 1
           ($quote (#:primitive #:eval (0 1) (#:return))))))
  ($equal? 10 (f-eval . 10))
  ($equal? 3 (f-eval + 1 2)))

;;
;; control flow
;;

($let ((f-tail
         (make-compiled-operative 0 #ignore
           ($quote
             (#:load 0
               #100=(#:if #:pair
                      (#:primitive #:cdr (#:acc) #100#)
                      (#:return)))))))
  ($equal? () (f-tail) (f-tail 1) (f-tail 1 2))
  ($equal? 1 (f-tail . 1) (f-tail 2 . 1)))

;;
;; a bigger program
;;

($let ()
  ($define! read-line-program
    ($quote
      (#:load 0
      (#:if #:pair
        (#:primitive #:car (#:acc)
        #0=(#:store 0
        (#:primitive #:io (0 (#:quote 1))
        (#:store 1
        (#:if #:eof
          (#:return)
          (#:primitive #:eq (1 (#:quote #\newline))
          (#:if #t
            (#:load (#:quote "") (#:return))
            (#:primitive #:combine
              ((#:standard open-output-string)
               (#:quote ())
               (#:standard (make-environment)))
            (#:store 2
            #2=(#:primitive #:io (2 1)
            (#:primitive #:io (0 (#:quote 1))
            (#:store 1
            (#:if #:eof
              #3=(#:primitive #:cons
                   (2 (#:quote ()))
                 (#:primitive #:combine
                   ((#:standard get-output-string)
                    #:acc
                    (#:standard (make-environment)))
                   (#:return)))
              (#:primitive #:eq (1 (#:quote #\newline))
              (#:if #t
                #3#
                #2#)))))))))))))))
        (#:primitive #:combine
          ((#:standard get-current-input-port)
           (#:quote ())
           (#:standard (make-environment)))
        (#:store 0
          #0#))))))
  ($define! read-line-2
    (wrap (make-compiled-operative 0 #ignore read-line-program)))
  (for-each
    ($lambda (input)
      ($equal?
        (with-input-from-string input read-line)
        (with-input-from-string input read-line-2)))
    (list "" "abcd" "ab\ncd" "\n\n")))

;; print pass/fail summary
;;
(summary)
