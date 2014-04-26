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

($define-ground-lambda! list-tabulate (n f)
  ($unless ($and? (integer? n) (not? (negative? n)))
    ($error list-tabulate "Invalid argument." n))
  ($unless (applicative? f)
    ($error list-tabulate "Invalid argument." f))
  ($define! g
    ($lambda (k a)
      ($if (<=? 0 k)
        (g (- k 1) (cons (apply f (list k)) a))
        a)))
  (g (- n 1) ()))

($define-ground-lambda! list->vector (l)
  ($let* ((n (length l))
          (v (make-vector n)))
    (list->vector-helper l v 0 n)
    v))
($define-private-lambda! list->vector-helper (l v k n)
  ($when (<? k n)
    (vector-set! v k (car l))
    (list->vector-helper (cdr l) v (+ k 1) n)))

($define-ground-lambda! vector->list (v)
  ($letrec ((f ($lambda (i a)
                 ($if (<=? 0 i)
                   (f (- i 1) (cons (vector-ref v i) a))
                   a))))
    (f (- (vector-length v) 1) ())))

($define-ground-lambda! list->bytevector (l)
  ($let* ((n (length l))
          (v (make-bytevector n)))
    (list->bytevector-helper l v 0 n)
    v))
($define-private-lambda! list->bytevector-helper (l v k n)
  ($when (<? k n)
    (bytevector-u8-set! v k (car l))
    (list->bytevector-helper (cdr l) v (+ k 1) n)))

($define-ground-lambda! bytevector->list (v)
  (list-tabulate
    (bytevector-length v)
    ($lambda (k) (bytevector-u8-ref v k))))

($define-ground-lambda! make-list (n . opt)
  ($letrec* ((x ($if (pair? opt) (car opt) #inert))
             (aux ($lambda (k t) ($if (<? 0 k) (aux (- k 1) (cons x t)) t))))
    (aux n ())))

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

($define-ground-wrapvau! string-map (f . lists) denv
  (list->string (apply map (cons f (map string->list lists)) denv)))

($define-ground-lambda! filter (accept? ls)
  (apply append
    (map ($lambda (x)
           ($if (apply accept? (list x))
                (list x)
                ()))
         ls)))

($define-ground-lambda! partition (accept? ls)
  ($let1 tmp
    (map ($lambda (x)
           ($if (apply accept? (list x))
                (cons (list x) ())
                (cons () (list x))))
         ls)
    (list (apply append (map car tmp))
          (apply append (map cdr tmp)))))

($define-ground-lambda! iota (count . rest)
  ($define! (start step)
    ($match rest
      (()           (list 0 1))
      ((start)      (list start 1))
      ((start step) (list start step))))
  (list-tabulate count ($lambda (k) (+ start (* step k)))))

($define-ground-lambda! substring (s k1 k2)
  ($letrec ((p (open-input-string s))
            (q (open-output-string))
            (f ($lambda (k)
                 ($let1 c (read-char p)
                   ($cond
                     ((<? k k1) (f (+ k 1)))
                     ((>=? k k2) (get-output-string q))
                     (#t (write-char c q) (f (+ k 1))))))))
    (f 0)))

($define-ground-lambda! vector args
  (list->vector args))

($define-ground-lambda! bytevector args
  (list->bytevector args))

($define-ground-wrapvau! vector-for-each (f v) denv
  ($define! loop
    ($lambda (i)
      ($when (<? i (vector-length v))
        (apply f (list (vector-ref v i)) denv)
        (loop (+ i 1)))))
  (loop 0))

($define-ground-lambda! vector-copy! (src dst)
  ($dotimes (i (vector-length src))
    (vector-set! dst i (vector-ref src i))))

($define-ground-lambda! binds? xs
  ($if ($and? (pair? xs) (environment? (car xs)))
    (eval (cons $binds? xs) private-environment)
    ($error1 binds? "Invalid argument structure." xs)))
