;;
;; 11-pidigits-stream.k
;;
;; Port of the "pidigits" benchmark from
;;
;;   http://benchmarksgame.alioth.debian.org/u64/benchmark.php?test=pidigits&lang=all&data=u64
;;
;; This version uses lazy stream and follows the paper referenced
;; on the abovementioned web page.
;;
;; The number of printed pi digits is 300. Bronze Age Lisp does very
;; badly on this benchmark because of poor bigint implementation.
;;

($define! stream
  ($lambda (next safe? prod kons start input)
    ($letrec ((go ($lambda (z xs)
                    ($define! y (next z))
                    ($cond
                      ((safe? z y)
                        (cons y ($lazy (go (prod z y) xs))))
                      (#t
                        ($define! (x . xs) (force xs))
                        (go (kons z x) xs))))))
      (go start input))))

($define! floor-extr
  ($lambda ((q r s t) x)
    (div (+ (* q x) r) (+ (* s x) t))))

($define! unit
  (list 1 0 0 1))

($define! comp
  ($lambda ((q r s t) (u v w x))
    (list (+ (* q u) (* r w))
          (+ (* q v) (* r x))
          (+ (* s u) (* t w))
          (+ (* s v) (* t x)))))

($define! map-stream
  ($lambda (f input)
    ($define! (h . t) (force input))
    (cons (f h) ($lazy (map-stream f t)))))

($define! iota-stream
  ($lambda (n)
    (cons n ($lazy (iota-stream (+ n 1))))))

($define! pi
  ($let ((init unit)
         (lfts (map-stream
                  ($lambda (k) (list k (+ (* 4 k) 2) 0 (+ (* 2 k) 1)))
                  (iota-stream 1)))
         (next ($lambda (z) (floor-extr z 3)))
         (safe ($lambda (z n) (=? n (floor-extr z 4))))
         (prod ($lambda (z n) (comp (list 10 (* -10 n) 0 1) z)))
         (kons comp))
  (stream next safe prod kons init lfts)))

($define! force-and-print-stream
  ($lambda (n input)
    ($cond
      ((positive? n)
        ($define! (x . xs) (force input))
        (write-char (digit->char x))
        (force-and-print-stream (- n 1) xs))
      (#t
        input))))

($define! print-counting
  ($lambda (n k input)
    ($when (positive? n)
      ($define! q (min n 10))
      ($define! input (force-and-print-stream q input))
      (display "\t:") (write (+ k q)) (newline)
      (print-counting (- n q) (+ k q) input))))

(print-counting 300 0 pi)
