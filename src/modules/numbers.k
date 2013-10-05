;;;
;;; numbers.k
;;;
;;; Implementation of arithmetic features, lisp part.
;;;

;; min, max
;;
($let ()
  ($define! make-minmax
    ($vau (impl neutral symbol) #ignore
      (bind-ground! symbol
        (make-unbounded-applicative
          (list 0 3)
          (list "app_min_max.A0"
                "app_min_max.A1"
                "app_min_max.A2"
                "app_min_max.A3")
          (make-operative
            "app_min_max.operate"
            (make-nonlisp-value impl)
            neutral
            symbol)))))
  (make-minmax "app_min_max.do_min" #e+infinity min)
  (make-minmax "app_min_max.do_max" #e-infinity max))

;; abs
;;
($define-ground-lambda! abs (x)
  ($if (negative? x) (negate x) x))

;; signum
;;
($define-ground-lambda! signum (x)
  ($cond
    ((positive? x)  1)
    ((negative? x) -1)
    (#t             0)))

;;
;; printing numbers (incl. bigints)
;;
($defun-privates!
  (powers (x b w ws)
    ($if (<? x w)
      ws
      (powers x b (* b w) (cons w ws))))
  (slow-div (a b q)
    ($if (>=? a b)
      (slow-div (- a b) b (+ q 1))
      (cons a q)))
  (print-digits (a (w . ws) p)
    ($let (((r . d) (slow-div a w 0)))
      (write-char (char-digit d) p)
      ($when (>? w 1) (print-digits r ws p))))
  (char-digit (d)
    (integer->char (+ ($if (<? d 10) #x30 #x37) d)))
  (print-positive-integer (n b p)
    (print-digits n (powers n b 1 ()) p))
  (print-integer (n b p)
    ($cond
      ((positive? n)
        (print-positive-integer n b p))
      ((negative? n)
        (write-char #\- p)
        (print-positive-integer (negate n) b p))
      (#t
        (write-char #\0 p)))))

($define-ground-lambda! number->string (x . r)
  ($cond
    ((eq? x #e+infinity) "#e+infinity")
    ((eq? x #e-infinity) "#e-infinity")
    ((integer? x)
       ($let1 b ($cond
                  ((null? r) 10)
                  (($and? (pair? r)
                          (null? (cdr r))
                          (integer? (car r))
                          (<=? 2 (car r) 36))
                      (car r))
                  (($and? (pair? r) (null? (cdr r)))
                    ($error1 number->string "invalid radix" (car r)))
                  (#t
                    ($error1 number->string "Invalid argument structure." (cons x r))))
         ($let1 p (open-output-string)
           (print-integer x b p)
           (get-output-string p))))
    (#t ($error1 number->string "Invalid argument." x))))

;; bigint division
;;

($defun-privates!
  (scaled-inverse (b m)
    ($define! n (+ m (integer-length b)))
    ($define! k (arithmetic-shift 1 n))
    ($define! newton
      ($lambda (y)
        ($let1 dy
               (arithmetic-shift (* y (- k (* b y)))
                                 (negate n))
          ($if (<=? -1 dy 1)
            (list y n)
            (newton (+ y dy))))))
    (newton (arithmetic-shift 1 m)))
  (fix-div (b q r)
    ($cond
      ((<? r 0)  (fix-div b (- q 1) (+ r b)))
      ((>=? r b) (fix-div b (+ q 1) (- r b)))
      (#t        (list q r))))
  (div-mod-pos (a b)
    ($let* (((y p) (scaled-inverse b (+ 4 (integer-length a))))
            (q     (arithmetic-shift (* a y) (negate p))))
      (fix-div b q (- a (* b q))))))

($define-ground-lambda! general-div-and-mod (a b)
  ;; The assembler part checks that both arguments
  ;; are finite and b is not zero.
  ($if (positive? b)
    ($cond
      ((positive? a)
        (div-mod-pos a b))
      ((negative? a)
        ($let (((q r) (div-mod-pos (negate a) b)))
          ($if (zero? r)
            (list (negate q) 0)
            (list (- -1 q) (- b r)))))
      (#t
        (list 0 0)))
    ($let (((q r) (general-div-and-mod a (negate b))))
        (list (negate q) r))))

;; div0 and mod0
;;
($define-ground-lambda! div0-and-mod0 (a b)
  ($let (((q r) (div-and-mod a b)))
    ($if (<? (* 2 r) (abs b))
      (list q r)
      (list (+ q (signum b)) (- r (abs b))))))

($define-ground-lambda! div0 x
  (car (apply div0-and-mod0 x)))

($define-ground-lambda! mod0 x
  (cadr (apply div0-and-mod0 x)))

;; gcm and lcd
;;

($defun-privates!
  (euclid (x y)
    ($if (zero? x) y (euclid (mod y x) x)))
  (gcd-bin (x y)
    (euclid (min x y) (max x y)))
  (lcm-bin (x y)
    (div (* x y) (euclid (min x y) (max x y)))))

($define-ground-lambda! gcd xs
  ($let1 ys (filter finite? xs)
    ($cond
      ((null? ys)
        #e+infinity)
      ((apply zero? ys)
        (apply error (cons "Undefined GCD" xs)))
      (#t
        (reduce (map abs ys) gcd-bin #ignore
                list* gcd-bin list*)))))

($define-ground-lambda! lcm xs
  ($let1 ys (filter positive? (map abs xs))
    ($cond
      ((not? (equal? (get-list-metrics xs)
                     (get-list-metrics ys)))
        (apply error (cons "Undefined LCM" xs)))
      ((not? (apply finite? ys))
        #e+infinity)
      (#t
        (reduce ys lcm-bin 1
                list* lcm-bin list*)))))
