;;;
;;; iterate.k
;;;
;;; Iteration form similar to Common Lisp macros loop and iterate.
;;;
;;; syntax:
;;;
;;;   ($iterate CLAUSE CLAUSE ...)
;;;
;;; where CLAUSE = (do EXPR EXPR ...)
;;;                (for FORMALS GENERATOR)
;;;                (when EXPR CLAUSE ...)
;;;                (unless EXPR CLAUSE ...)
;;;                (while EXPR)
;;;                (until EXPR)
;;;                (repeat NUMBER)
;;;                (collecting EXPR)
;;;                (adjoining EXPR)
;;;                (appending EXPR)
;;;                (sum EXPR)
;;;                (minimizing EXPR)
;;;                (maximizing EXPR)
;;;                (counting EXPR)
;;;                (always EXPR)
;;;                (never EXPR)
;;;                (thereis EXPR)
;;;                (finding EXPR {such-that|minimizing|maximizing} EXPR)
;;;
;;;   and GENERATOR = next EXPR
;;;                   in LIST [with-index VARIABLE]
;;;                   in-vector VECTOR [with-index VARIABLE]
;;;                   in-string STRING [with-index VARIABLE]
;;;                   from NUMBER
;;;                   from NUMBER {to|downto|below|above} NUMBER
;;;                   from NUMBER {to|downto|below|above} NUMBER step NUMBER
;;;                   previous EXPR [initially EXPR] [back NUMBER]
;;;                   initially EXPR [then EXPR]
;;;
;;; Note the difference between (when ...) and ($when ...). The FEXPR
;;; $iterate will look for clauses inside (when ...), but not inside
;;; ($when ...).
;;;
;;; examples:
;;;
;;; (t1) prints (a 100) (b 101) (c 102)
;;; (t2) => (-2 -12 -70 -78)
;;; (t3) => 5
;;; (t4) => 55
;;; (t5) => 3
;;; (t6) => 7
;;; (t7) => (100 101 ... 149 150)
;;; (t8) => (#\a #\x #\b #\x #\c #\a #\d #\b)
;;; (t9) => (2 1 0 3 4)
;;;

($define! t1
  ($lambda ()
    ($iterate (repeat 3)
              (for i in (list #\a #\b #\c #\d))
              (for j from 100)
              (do (display (list i j))))
    (newline)))

($define! t2
  ($lambda ()
    ($iterate (for i in (list 1 2 3 12 70 71 78))
              (when (even? i)
                 (collecting (negate i))))))

($define! t3
  ($lambda ()
    ($iterate (for i from 0 below 10)
              (finding i minimizing (abs (- (* i i) 30))))))

($define! t4
  ($lambda ()
    ($iterate (for i from 1 below 6)
              (sum (* i i)))))

($define! t5
  ($lambda ()
    ($iterate (for i from 10)
              (while (<? (* i i) 200))
              (counting (even? i)))))

($define! t6
  ($lambda ()
    ($iterate (for i from 0)
              (finding i such-that (=? (* i i) 49)))))

($define! t7
  ($lambda ()
    ($iterate (for i from 100)
              (for j from 200)
              (collecting i)
              (while (<? (+ i j) 400)))))

($define! t8
  ($lambda ()
    ($iterate (for u in-string "abcd")
              (for v previous u back 2 initially #\x)
              (appending (list u v)))))

($define! t9
  ($lambda ()
    ($iterate (for k from 1 to 7)
              (adjoining (abs (- 3 k))))))

;;;
;;; more examples:
;;;
;;;  diff2 - computes 2nd difference
;;;  wc-l  - counts newlines in a string
;;;

($define! diff2
  ($lambda (xs)
    ($iterate (for x in xs)
              (for y previous x initially 0)
              (for z previous (- x y) initially 0)
              (collecting (- x y z)))))

($define! wc-l
  ($lambda (s)
    ($iterate (for c in-string s)
              (counting (eq? c #\newline)))))

;;;
;;; Implementation.
;;;

($provide! ($iterate
            do
            collecting adjoining appending
            maximizing minimizing sum counting
            always never thereis
            repeat while until
            for next in in-vector in-string from initially previous
            finding
            terminate return
            when unless)

  ($define! (bind-ivars ivars)
    (make-keyed-dynamic-variable))

  ($define! $iterate
    ($vau clauses denv
      ($let/cc k
        (bind-ivars
          ($bindings->environment
            (exit-continuation k)
            (final-combiner ($vau #ignore #ignore #inert)))
          ($lambda ()
            ($define! xenv (make-environment denv))
            ($define! body
              (list (cons $sequence (eval (cons list clauses) xenv))))
            (set-cdr! body body)
            (eval-sequence body xenv))))))

  ;;
  ;; private helpers
  ;;

  ($define! $vau-dictionary
    ($vau definitions denv
      (eval (cons $bindings->environment
                  (map ($lambda ((name . rest))
                        (list name (eval (list* $vau rest) denv)))
                      definitions))
            denv)))

  ($define! $iter-do
    ($vau (eformal bindings final . body) denv
      ($define! local-env
        (eval (list $let-redirect denv bindings
                    (list get-current-environment))
              denv))
      (eval (list $define! eformal local-env) local-env)
      ($unless (ignore? final)
        ($set! (ivars) final-combiner
          (eval (list* $vau () #ignore final) local-env)))
      (list (eval (list* $vau () #ignore body) local-env))))

  ($define! key-match
    ($lambda (ps vs acc)
      ($cond
        (($and? (null? ps) (null? vs))
          acc)
        ((ignore? ps)
          acc)
        (($and? (pair? ps) (pair? vs) (pair? (cdr vs)))
          ($let (((p1 p2 . ps) ps)
                 ((v1 v2 . vs) vs))
            ($if (eq? p1 v1)
              (key-match ps vs
                         (cons (list ($if (pair? p2) (car p2) p2) v2)
                               acc))
              #f)))
        (($and? (pair? ps) (null? vs) (pair? (cadr ps)))
          ($let (((p1 (p2 default) . ps) ps))
            (key-match ps vs (cons (list p2 default) acc))))
        (#t
          #f))))

  ($define! $key-case
    ($vau (value venv . clauses) denv
      ($define! value (eval value denv))
      ($define! venv (eval venv denv))
      #1=($let* (((pattern . body) (car clauses))
                 (bindings (key-match pattern value ())))
          ($cond
            ((eq? bindings #f)
              ($let ((clauses (cdr clauses))) #1#))
            ((environment? venv)
              (eval (list* $let-redirect denv bindings body)
                    (eval venv denv)))
            (#t
              (for-each ($lambda ((lhs rhs)) (set! denv lhs rhs))
                        bindings)
              (eval-sequence body denv))))))

  ;;
  ;; basic clauses
  ;;

  ($define! do
    ($vau forms denv
      (cons $sequence forms)))

  ;;
  ;; list accumulation
  ;;

  ($define! collecting
    ($vau (x) denv
      ($iter-do
          private ((xs ()))
          ((reverse xs))
        ($set! private xs (cons (eval x denv) xs)))))

  ($define! adjoining-test
    ($lambda (eqv?)
      ($cond
        ((eq? eqv? eq?)      memq?)
        ((eq? eqv? equal?)   member?)
        ((applicative? eqv?) ($lambda (x ys)
                               ($iterate (for y in ys)
                                         (thereis (eqv? x y)))))
        (#t                  (error "Invalid equivalence predicate."
                                    eqv?)))))

  ($define! adjoining
    ($vau (x . rest) denv
      ($key-case
        rest #ignore
        ((test (t eq?))
          ($iter-do private
                    ((t? (adjoining-test (eval t denv)))
                     (xs ()))
                    ((reverse xs))
            ($define! x (eval x denv))
            ($unless (t? x xs)
              ($set! private xs (cons x xs)))))
        (#ignore
          (error "Invalid $iterate clause"
            (list* ($quote adjoining) x rest))))))

  ($define! appending
    ($vau (x) denv
      ($iter-do private ((xs ()))
                ((apply append (reverse xs)))
        ($set! private xs (cons (eval x denv) xs)))))

  ;;
  ;; numeric accumulation
  ;;

  ($define! maximizing
    ($vau (x) denv
      ($iter-do private ((m #e-infinity)) (m)
        ($set! private m (max m (eval x denv))))))

  ($define! minimizing
    ($vau (x) denv
      ($iter-do private ((m #e+infinity)) (m)
        ($set! private m (min m (eval x denv))))))

  ($define! sum
    ($vau (x) denv
      ($iter-do private ((m 0)) (m)
        ($set! private m (+ m (eval x denv))))))

  ($define! counting
    ($vau (x) denv
      ($iter-do private ((n 0)) (n)
        ($when (eval x denv)
          ($set! private n (+ n 1))))))

  ;;
  ;; boolean accumulation
  ;;

  ($define! always
    ($vau (x) denv
      ($iter-do #ignore () (#t)
        ($unless (eval x denv) (return #f)))))

  ($define! never
    ($vau (x) denv
      ($iter-do #ignore () (#t)
        ($when (eval x denv) (return #f)))))

  ($define! thereis
    ($vau (x) denv
      ($iter-do #ignore () (#f)
        ($when (eval x denv) (return #t)))))

  ;;
  ;; control flow 
  ;;

  ($define! while
    ($vau (expr) denv
      ($iter-do #ignore () #ignore
        ($unless (eval expr denv) (terminate)))))

  ($define! until
    ($vau (expr) denv
      ($iter-do #ignore () #ignore
        ($when (eval expr denv) (terminate)))))

  ($define! terminate
    ($lambda ()
      ($import! (ivars) exit-continuation final-combiner)
      (apply-continuation exit-continuation (final-combiner))))

  ($define! return
    ($lambda (value)
      ($import! (ivars) exit-continuation)
      (apply-continuation exit-continuation value)))

  ($define! when
    ($vau (expr . more-clauses) xenv
      (list* $when expr (eval (cons list more-clauses) xenv))))

  ($define! unless
    ($vau (expr . more-clauses) xenv
      (list* $when expr (eval (cons list more-clauses) xenv))))

  ;;
  ;; binding and destructuring
  ;;

  ($define! for
    ($vau (var . rest) denv
      (list $define! var (eval rest denv))))

  ;;
  ;; general generator
  ;;

  ($define! next
    ($vau (expr) denv
      expr))

  ;;
  ;; list, vector and string elements
  ;;

  ($define! in
    ($vau (xs . rest) denv
      ($key-case rest #ignore
        ((with-index var)
          (list $sequence
                (eval (list for var from 0) denv)
                (eval (list in xs) denv)))
        (()
          ($iter-do private ((xs (eval xs denv))) #ignore
            ($if (pair? xs)
              ($let ((x (car xs))) ($set! private xs (cdr xs)) x)
              (terminate))))
        (#ignore
          (error "Invalid $iterate clause"
            (list* ($quote in-vector) v rest))))))

  ($define! in-vector
    ($vau (v . rest) denv
      ($key-case rest #ignore
        ((with-index var)
          (list $sequence
                (eval (list for var from 0) denv)
                (eval (list in-vector v) denv)))
        (()
          ($iter-do private ((k 0) (v (eval v denv))) #ignore
            ($if (<? k (vector-length v))
              ($let ((x (vector-ref v k)))
                ($set! private k (+ k 1))
                x)
              (terminate))))
        (#ignore
          (error "Invalid $iterate clause"
            (list* ($quote in-vector) v rest))))))

  ($define! in-string
    ($vau (str . rest) denv
      ($key-case rest #ignore
        ((with-index var)
          (list $sequence
                (eval (list for var from 0) denv)
                (eval (list in-string str) denv)))
        (()
          ($iter-do #ignore
                    ((p (open-input-string (eval str denv))))
                    #ignore
            ($let ((c (read-char p)))
              ($if (char? c)
                c
                (terminate)))))
        (#ignore
          (error "Invalid $iterate clause"
            (list* ($quote in-string) v rest))))))

  ;;
  ;; integer counters
  ;;

  ($define! repeat
    ($lambda (n)
      ($iter-do private ((n n)) #ignore
        ($if (positive? n)
          ($set! private n (- n 1))
          (terminate)))))

  ($define! integer-driver
    ($lambda (count start step)
      ($iter-do private ((n count) (k (- start step))) #ignore
        ($cond
          ((positive? n)
            ($set! private n (- n 1))
            ($set! private k (+ k step))
            k)
          (#t
            (terminate))))))

  ($define! from
    ($vau (start . rest) denv
      ($define! α (eval start denv))
      ($key-case rest denv
        ((to β step (γ 1))
          (integer-driver (+ 1 (div (- β α) γ)) α γ))
        ((below β step (γ 1))
          ($let (((q r) (div-and-mod (- β α) γ)))
            (integer-driver ($if (zero? r) q (+ q 1)) α γ)))
        ((downto β step (γ 1))
          (integer-driver (+ 1 (div (- α β) γ)) α (negate γ)))
        ((above β step (γ 1))
          ($let (((q r) (div-and-mod (- β α) γ)))
            (integer-driver ($if (zero? r) q (+ q 1)) α (negate γ))))
        (()
          (integer-driver #e+infinity α 1))
        (#ignore
          (error "Invalid $iterate clause"
                 (list* ($quote from) start rest))))))

  ;;
  ;; initial and previous values
  ;;

  ($define! previous
    ($vau (expr . rest) denv
      ($key-case rest #ignore
        ((initially (φ #inert) back (ν 1))
          #1=($iter-do private
                    ((v (make-vector ν (eval φ denv))) (k 0))
                    #ignore
            ($let ((new (eval expr denv))
                   (old (vector-ref v k)))
              (vector-set! v k new)
              ($set! private k (mod (+ k 1) ν))
              old)))
        ((back (ν 1) initially (φ #inert))
          #1#)
        (#ignore
          (error "Invalid $iterate clause"
                 (list* ($quote previous) expr rest))))))

  ($define! initially
    ($vau (e1 . rest) denv
      ($key-case rest #ignore
        (()
         (list $quote (eval e1 denv)))
        ((then e2)
          ($iter-do private ((first? #t) (value (eval e1 denv))) #ignore
            ($if first?
              ($sequence ($set! private first? #f) value)
              (eval e2 denv))))
        (#ignore
          (error "Invalid $iterate clause"
                 (list* ($quote initially) e1 rest))))))

  ;;
  ;; finding elements
  ;;

  ($define! finding-optimizing
    ($lambda (item expr denv compare?)
      ($iter-do private
                ((optval #f) (argopt #inert))
                (($if (number? optval)
                  argopt
                  (error "Extremum not found." item expr)))
        ($let ((v (eval expr denv)))
          ($when ($or? (not? (number? optval)) (compare? v optval))
            ($set! private optval v)
            ($set! private argopt (eval item denv))
            ($set! private found #t))))))

  ($define! finding-dictionary
    ($vau-dictionary
      (such-that (item expr) denv
        ($iter-do #ignore ()
                  ((error "Item not found." item expr))
          ($when (eval expr denv)
            (return (eval item denv)))))
      (minimizing (item expr) denv
        (finding-optimizing item expr denv <=?))
      (maximizing (item expr) denv
        (finding-optimizing item expr denv >=?))))

  ($define! finding
    ($vau (item how expr) denv
      (eval (list (eval how finding-dictionary) item expr)
            denv))))
