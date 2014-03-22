;;;
;;; 307-allocator-limits.k
;;;
;;; Test handling of out-of-memory conditions.
;;;

($define! run-test
  ($lambda (exprs msg)
    ($let
      ((b (list "error" msg #inert #inert))
       ;; Discard result of "exprs" to free memory before evaluating the test.
       (a (protect-eval (list $sequence (cons $sequence exprs) #inert)
                        (make-kernel-standard-environment))))
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

;; Bigints
;;
($om
  (arithmetic-shift -6291456 65152345))
($om
  (expt 12345 67890))

;; Allocation of various objects.
;;
($define! om-repeat
  ($lambda (start step)
    ($letrec ((f ($lambda (x) (f (step x))))
              (t ($lambda (n)
                   ((wrap $om)
                     (list collect-garbage)
                     (list make-vector n)
                     (list f (list $quote start)))
                   ($when (>? n 0)
                     (t (- n 128))))))
      (t 1024))))

(om-repeat (make-environment) ($lambda (x) (make-environment x)))
(om-repeat (make-environment) ($lambda (x) (make-environment x x)))
(om-repeat (make-environment) ($lambda (x) (make-environment x x x)))

(om-repeat () ($lambda (x) ($lambda (y) x)))
(om-repeat () ($lambda (x) ($lambda (p q r) x x)))
(om-repeat () ($lambda (x) ($vau (y) #ignore x)))
(om-repeat () ($lambda (x) ($vau (y) env e)))

;; This takes ages to run:
;;
;; (om-repeat 2 ($lambda (x) (* x x)))
;; (om-repeat 2 ($lambda (n) (* n (+ 1 n))))
;; (om-repeat (list 2 3) ($lambda ((x y)) (list y (* x y))))

(summary)
