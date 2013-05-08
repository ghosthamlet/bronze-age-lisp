;;;
;;; utilities.k
;;;
;;; General utility functions.
;;;

;;
;; (string-append* OBJECT...) => STRING
;; (symbol-append* OBJECT...) => SYMBOL
;;
($provide! (string-append* symbol-append*)
  ($define! object->string
    ($lambda (x)
      ($cond
        ((string? x) x)
        ((symbol? x) (symbol->string x))
        ((number? x) (number->string x))
        (#t (error "invalid argument" object->string x)))))
  ($define! string-append*
    ($lambda args
      (apply string-append (map object->string args))))
  ($define! symbol-append*
    ($lambda args
      (string->symbol (apply string-append* args)))))

;;
;; ($for (VAR LOW HIGH) . BODY)
;;
;; Evaluates BODY (HIGH - LOW + 1) times, with the symbol VAR
;; bound to LOW, LOW + 1, ... HIGH - 1, HIGH, respectively.
;;
($define! $for
  ($vau ((var a b) . body) denv
    ($let*
      ((a (eval a denv))
       (b (eval b denv))
       (run (eval (list* $lambda (list var) body) denv)))
      ($letrec
        ((aux ($lambda (k) ($when (<=? k b) (run k) (aux (+ k 1))))))
        (aux a)))))

;;
;; (partition PREDICATE LIST) => (LIST-TRUE LIST-FALSE)
;;
($define! partition
  ($letrec
    ( (aux ($lambda (pred xs acc-t acc-f)
        ($if (null? xs)
          (list (reverse acc-t) (reverse acc-f))
          ($if (pred (car xs))
            (aux pred (cdr xs) (cons (car xs) acc-t) acc-f)
            (aux pred (cdr xs) acc-t (cons (car xs) acc-f)))))))
    ($lambda (pred xs)
      (aux pred xs () ()))))

;;
;; ($define-add! SYMBOL VALUE ADD)
;;
;; Binds SYMBOL to VALUE in the dynamic environment.
;; Moreover, it binds SYMBOL-set! to an applicative such that
;; (SYMBOL-set! X) rebinds SYMBOL to the result of
;; (ADD X Y), where Y is the current value.
;;
($define! $define-add!
  ($vau (sym init add) denv
    ($let*
      ((initial-value (eval init denv))
       (add (eval add denv))
       (setter ($lambda (x) (set! denv sym (add x (eval sym denv))))))
      (set! denv sym initial-value)
      (eval (list $define! (symbol-append* sym "-add!") setter) denv))))

;;
;; (list-take LIST N) => prefix of LIST of length N
;;
($define! list-take
  ($lambda (xs n)
    ($if (<? n 0)
      (cons (car xs) (list-take (cdr xs) (- n 1)))
      ())))

;;
;; (align X A) => Y,  where X <= Y < X + A,
;;                      and X = k * A for some integer k,
;;
;; assuming X >= 0 and A > 0
;;
($define! align
  ($lambda (x a)
    (+ x (mod (- 0 x) a))))

;;
;; (make-dictionary) => DICTIONARY
;; (dictionary-add! DICTIONARY KEY VALUE) => #inert
;; (dictionary-assoc DICTIONARY KEY) => (key . value) or ()
;;
;; (equal?)-compatible hash tables
;;

($provide!
  (make-dictionary
   dictionary-add! dictionary-exists? dictionary-assoc
   dictionary-getter)

  ($define! size 997)

  ($define! hchr
    ($lambda (x)
      ($if (char? x) (char->integer x) 251)))

  ($define! hstr
    ($lambda (s)
      ($let ((p (open-input-string s)))
        (mod (+
               (* 157 (hchr (read-char p)))
               (* 163 (hchr (read-char p)))
               (* 167 (hchr (read-char p))))
             size))))

  ($define! hash-structure
    ($lambda (x n)
      ($cond
        ((pair? x)
          ($if (<? 0 n)
            (+ (* 11 (hash-structure (car x) (- n 2)))
               (* 13 (hash-structure (cdr x) (- n 1))))
            17))
        ((null? x) 53)
        ((integer? x) (* 2 x))
        ((string? x) (* 23 (hstr x)))
        ((symbol? x) (* 29 (hstr (symbol->string x))))
        ((keyword? x) (* 29 (hstr (keyword->string x))))
        ((char? x) (* 31 (char->integer x)))
        ((boolean? x) ($if x 37 41))
        ((inert? x) 43)
        ((ignore? x) 47)
        (#t 59))))

  ($define! hash
    ($lambda (x)
      (mod (hash-structure x 2) size)))

  ($define! make-dictionary
    ($lambda ()
      (make-vector size ())))

  ($define! dictionary-add!
    ($lambda (d k v)
      ($let ((i (hash k)))
        (vector-set! d i (cons (cons k v) (vector-ref d i))))))

  ($define! dictionary-assoc
    ($lambda (d k)
      (assoc k (vector-ref d (hash k)))))

  ($define! dictionary-getter
    ($lambda (d)
      ($lambda (k)
        ($let ((v (dictionary-assoc d k)))
          ($if (null? v)
            (error "key not found in dictionary" k)
            (cdr v))))))

  ($define! dictionary-exists?
    ($lambda (d k)
      (pair? (assoc k (vector-ref d (hash k)))))))
