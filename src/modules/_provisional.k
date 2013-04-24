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

($define-ground-lambda! max args
  ($let1 n (length args)
    ($cond ((=? n 1) (car args))
           ((=? n 2) ($let (((x y) args)) ($if (<? x y) y x)))
           (#t (error "max - not yet implemented" args)))))

($define-ground-lambda! min args
  ($let1 n (length args)
    ($cond ((=? n 1) (car args))
           ((=? n 2) ($let (((x y) args)) ($if (<? x y) x y)))
           (#t (error "min - not yet implemented" args)))))

($define-ground-lambda! make-string (n . opt)
  ($define! c ($if (pair? opt) (car opt) #\space))
  ($define! p (open-output-string))
  ($define! f ($lambda (k)
                ($when (>? k 0)
                  (write-char c p)
                  (f (- k 1)))))
  (f n)
  (get-output-string p))

($define-ground-lambda! list->string (chars)
  ($let ((p (open-output-string)))
    (for-each ($lambda (x) (write-char x p)) chars)
    (get-output-string p)))

($define-ground-lambda! string->list (s)
  ($letrec ((p (open-input-string s))
            (f ($lambda ()
                 ($let1 c (read-char p)
                   ($if (eof-object? c)
                     ()
                     (cons c (f)))))))
    (f)))

($define-ground-lambda! filter (accept? ls)
  (apply append
    (map ($lambda (x)
           ($if (apply accept? (list x))
                (list x)
                ()))
         ls)))