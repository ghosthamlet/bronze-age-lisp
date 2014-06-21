;;;
;;; 318-continuation-capture.k
;;;
;;; Test continuation capture in (map ...) and (for-each ...).
;;;

($define! $test-capture
  ($vau (expr (input-1 output-1) (input-2 output-2))  denv
    ($define! fut
      (eval (list $lambda ((unwrap list) capture!) expr) denv))
    ($define! env
      ($let/cc abort
        ($define! env (get-current-environment))
        ($define! note-1!
          ($lambda (x)
            ($set! env sut-1 x)
            ($set! env note! note-2!)))
        ($define! note-2!
          ($lambda (x)
            ($set! env sut-2 x)
            (apply-continuation abort env)))
        ($define! note!
          note-1!)
        ($define! capture!
          ($lambda ()
            ($let/cc k
              ($set! env captured k)
              input-1)))
        ($define! value (protect-call fut (list capture!)))
        (note! value)
        ($if ($binds? env captured)
          (apply-continuation captured input-2)
          value)))
    ($if ($and? (environment? env) ($binds? env sut-1 sut-2 captured))
      ($let ((sut ($remote-eval (list sut-1 sut-2) env))
             (ref (list (list "return" output-1) (list "return" output-2))))
        ($if (equal? sut ref)
          (pass)
          (fail-with-report "let/cc" expr sut ref)))
      (fail-with-report "let/cc" expr env "environment"))))

($test-capture
  (list 0 (capture!) 2)
  (-1 (0 -1 2))
  (-2 (0 -2 2)))

($test-capture
  (map ($lambda (x) ($if (=? x 1) (capture!) x))
       (list 0 1 2))
  (-1 (0 -1 2))
  (-2 (0 -2 2)))

($test-capture
  (map ($lambda (x y)
         ($if (=? x 1) (capture!) (+ x y)))
       (list 0 1 2)
       (list 3 4 5))
  (-1 (3 -1 7))
  (-2 (3 -2 7)))

($test-capture
  ($letrec ((ls ()) (env (get-current-environment)))
    (for-each
      ($lambda (x)
        ($set! env ls (cons ($if (=? x 1) (capture!) x) ls)))
      (list 0 1 2))
    ls)
  (-1 (2 -1 0))
  (-2 (2 -2 2 -1 0)))

(summary)
