;;;
;;; 307-allocator-limits.k
;;;
;;; Test handling of out-of-memory conditions.
;;;

($define! run-test
  ($lambda (exprs msg)
    ($let
      ((a (protect-eval (cons $sequence exprs)
                        (make-kernel-standard-environment)))
       (b (list "error" msg #inert #inert)))
      ($if (equal? a b)
        (pass)
        (fail-with-report
          "out-of-memory"
          exprs
          a b)))))

($define! $om
  ($vau exprs #ignore
    (run-test exprs "Out of memory (lisp).")))

($define! $ob
  ($vau exprs #ignore
    (run-test exprs "Out of memory (blobs).")))

;; Memory exhaustion is side effect of evaluating
;; some cyclic objects.
;;
($om #1=($sequence #1# 1))
($om #1=($if #1# 1 2))
($om #1=($when #1# 1))
($om #1=(eval #1# (make-environment)))

;; Unbounded recursion.
;;
($om
  ($letrec ((f ($lambda (n x) (f (+ n 1) (cons n x)))))
    (f 0 ())))
($om
  ($letrec ((f ($lambda (n) (+ 1 (f (+ n 1))))))
    (f 0)))

;; String allocation.
;;
($ob
  ($letrec* ((f ($lambda (x) (f (string-append x x)))))
    (f "x")))
($ob
  ($letrec* ((f ($lambda (x) (f (string-append x x x x x x x)))))
    (f "x")))

;; Unbounded recursion and string ports
;;
($ob
  ($letrec* ((p (open-output-string))
             (f ($lambda () (write-char #\x p) (f))))
    (f)))
($ob
  ($letrec* ((f ($lambda () (write-char #\x) (f))))
    (with-output-to-string f)))

;; String ports.
;;

;; Allocation of blobs.
;;
;; TODO: Unbounded recursion and allocation of bigints.
;;
;;($om ($letrec ((f ($lambda (n) #|(write (list ">" n "<")) (newline)|#(f (* n (+ 1 n)))))) (f 2)))
;;($om ($letrec ((f ($lambda (n) (* n (f (+ 1 n)))))) (f 2)))

(summary)
