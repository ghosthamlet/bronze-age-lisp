;;;
;;; provisional.k
;;;
;;; Provisional definitions.
;;;
;;; The definitions are incomplete and not always correct.
;;; The purpose is to get quickly to reasonable level
;;; of compatibility with klisp.
;;;
;;; TODO: fix and/or port to assembly language
;;;

($define-ground-lambda! reverse (a)
  (naive-reverse a ()))

($define-private-lambda! naive-reverse (a b)
  ($if (pair? a)
    (naive-reverse (cdr a) (cons (car a) b))
    b))

($define-ground-lambda! list->vector (l)
  ($let* ((n (length l))
          (v (make-vector n)))
    (list->vector-helper l v 0 n)
    v))
($define-private-lambda! list->vector-helper (l v k n)
  ($when (<? k n)
    (vector-set! v k (car l))
    (list->vector-helper (cdr l) v (+ k 1) n)))

($define-ground-lambda! make-list (n . opt)
  ($letrec* ((x ($if (pair? opt) (car opt) #inert))
             (aux ($lambda (k t) ($if (<? 0 k) (aux (- k 1) (cons x t)) t))))
    (aux n ())))

($define-ground-lambda! max (x y) ($if (<? x y) y x))
($define-ground-lambda! min (x y) ($if (<? x y) x y))

($define-ground-lambda! make-string (n . opt)
  ($define! c ($if (pair? opt) (car opt) #\space))
  ($define! p (open-output-string))
  ($define! f ($lambda (k)
                ($when (>? k 0)
                  (write-char c p)
                  (f (- k 1)))))
  (f n)
  (get-output-string p))
