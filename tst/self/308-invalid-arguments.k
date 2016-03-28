;;;
;;; 308-invalid-arguments.k
;;;
;;; Test error handling in build-in combiners.
;;;

($define! check-error
  ($lambda (expr error-info)
    ($let*
      (((msgs irritants source) error-info)
       (a (protect-eval expr
                        (make-kernel-standard-environment)))
       (b (cons "error" error-info))
       (ok ($and? (equal? (car a) "error")
                  (member? (cadr a) msgs)
                  (equal? (caddr a) irritants)
                  ($if (ignore? source) #t (equal? (cadddr a) source)))))
      ($if ok
        (pass)
        (fail-with-report (car msgs) expr a b)))))

;; Most combiners signal an error, if the parameter tree
;; is not a list (the only exception is the non-standard
;; operative $quote*)
;;

($define! invalid-argument-structure-messages
  (list "Invalid argument structure."
        "Cannot traverse list structure."
        "Match failure"))

($define! invalid-argument-structure-messages-unwrap
  (cons "Invalid argument." invalid-argument-structure-messages))

($define! $nonlist-test
  ($vau ((#:nounwrap . nounwrap) . symbols) #ignore
    ($define! test-pair
      ($lambda (symbol nonlist)
        (check-error (cons symbol nonlist)
                     (list invalid-argument-structure-messages
                           nonlist
                           symbol))
        ($when ($and? (not? (member? symbol nounwrap))
                      (applicative? (eval symbol (make-kernel-standard-environment))))
          (check-error (cons (list unwrap symbol) nonlist)
                       (list invalid-argument-structure-messages-unwrap
                             nonlist
                             #ignore)))))
    (for-each
      ($lambda (arg)
        (for-each
          ($lambda (sym) (test-pair sym arg))
          symbols))
      (list #t #f #inert #ignore 0 -1 1 (make-environment)))))

($nonlist-test
    (#:nounwrap list append)
  boolean? not? and? or? $and? $or?
  eq? equal?
  symbol? symbol->string string->symbol
  inert? $if $sequence $cond for-each $when $unless
  pair? null? immutable-pair? mutable-pair? cons set-car! set-cdr!
    copy-es-immutable list list*
    car cdr
    caar cadr cdar cddr
    caaar caadr cadar caddr cdaar cdadr cddar cdddr
    caaaar cddddr
    reverse list-tail encycle! length list-ref append
    assoc member? finite-list? countable-list?
    assq memq?
    get-list-metrics
    ; make-list reduce filter append! copy-es
  environment? ignore? $binds?
    make-environment $define! $set!
    $let $letrec $let* $letrec* $let-redirect $let-safe
    eval $remote-eval
    get-current-environment make-kernel-standard-environment
    $provide! $import!
  operative? applicative? combiner?
    $vau $lambda wrap unwrap apply map
  continuation? call/cc $let/cc exit
    extend-continuation guard-continuation guard-dynamic-extent
    continuation->applicative apply-continuation
  make-encapsulation-type
  promise? force $lazy memoize
    ; $delay
  make-keyed-dynamic-variable
  make-keyed-static-variable
  number? integer? finite?
    =? <? >? <=? >=?
    + - *
    zero? positive? negative?
    div mod div-and-mod
    abs max min
    string->number number->string
    lcm gcd ; expt
    div0 mod0 div0-and-mod0
    u8?
    negate
  string? string-length string-ref string-append
    make-string string->list list->string
    ; string=? string<? ...
    ; substring string-copy string
  char?
    char<=? ; char=? char<? ...
    char-alphabetic? char-whitespace? ; char-numeric?
    char->integer integer->char
    char-digit? char->digit digit->char
  port?
    ;input-port? output-port?
    ;textual-port? binary-port?
    with-input-from-file with-output-to-file
    get-current-input-port get-current-output-port
    get-current-error-port
    open-input-file open-binary-input-file
    open-output-file open-binary-output-file
    open-input-string open-output-string get-output-string
    close-port close-input-port close-output-port
    read write write-simple display newline
    write-char read-char peek-char ; char-ready?
    write-string
    ; write-u8 ..
    eof-object?
    read-line
    flush-output-port
    call-with-input-file call-with-output-file
    load get-module
    ; require ...
  vector? vector-length vector-ref vector-set!
    make-vector
    ;immutable-vector? mutable-vector?
    ;vector vector->list list->vector ...
  error-object?
    error
    error-object-message
    error-object-irritants
    error-object-source
  ; bytevectors libraries system
  )

;; Some combiners expect fixed number of arguments.
;;
($define! $narg-test
  ($vau (n1 n2 . symbols) #ignore
    ($define! test-pair
      ($lambda (symbol arglist)
        (check-error (cons symbol arglist)
                     (list invalid-argument-structure-messages
                           arglist
                           symbol))))
    ($define! genlist
      ($lambda (n)
        ($if (=? n 0)
          ()
          (cons n (genlist (- n 1))))))
    (for-each
      ($lambda (symbol)
        ($when (>=? n1 1) (test-pair symbol ()))
        ($when (>=? n1 2) (test-pair symbol (list #t)))
        ($when (>=? n1 3) (test-pair symbol (genlist (- n1 1))))
        ($when (finite? n2) (test-pair symbol (genlist (+ n2 1)))))
      symbols)))

($narg-test 1 1
  not?
  symbol->string string->symbol
  car cdr caar cadr cdar cddr caaar cdddr caaaar cddddr
    reverse length get-list-metrics
  ; TODO
  )

($narg-test 1 2
  number->string
  ;TODO
  )

($narg-test 2 2
  cons set-car! set-cdr!
  assoc assq member? memq?
  ;TODO
  )

($narg-test 3 3 $if)
($narg-test 1 #e+infinity $when $unless format)
($narg-test 2 #e+infinity map for-each)

;; Type errors in applicative arguments.
;;
($define! test-values
  (list
    ($quote* #:boolean #t #f)
    ($quote* #:symbol blabla |1 x 3|)
    ($quote* #:string "quaqua" "9 t")
    (list #:environment (make-environment) (make-kernel-standard-environment))
    (list #:combiner/applicative car $if)
    (list #:continuation error-continuation root-continuation)
    ($quote* #:number 0 1 999999999999999999999 #e+infinity)
    (list* #:pair (list (list root-continuation ($lambda () ())))
      ($quote* (1 2) (#t #f) (#inert ()) ((1 2) (3 4))))))

($define! $type-test
  ($vau (symbol . arg-types) #ignore
    ($define! test-combination
      ($lambda ((irritant arglist))
        ;(write (list #:test-combination symbol arglist)) (newline)
        (check-error (cons (list unwrap symbol) arglist)
                     (list type-error-messages
                           irritant
                           symbol))))
    ($define! good-instance
      ($lambda (t)
        ($if (eq? t #:any)
          #:anything
          (cadr (assoc t test-values)))))
    ($define! genlist
      ($lambda (pf sf)
        ($cond
          (($and? (pair? sf) (eq? (car sf) #:any))
           (genlist
             (append pf (list #:anything))
             (cdr sf)))
          ((pair? sf)
           ($let ((bad-instances
                   (apply append
                     (map cdr
                       (filter
                         ($lambda (v) (not? (eq? (car sf) (car v))))
                         test-values)))))
            (append
              (map
                ($lambda (i)
                  (list i
                        (append pf
                                (list i)
                                (map
                                  good-instance
                                  (cdr sf)))))
                bad-instances)
              (genlist
                (append pf (list (good-instance (car sf))))
                (cdr sf)))))
          (#t ()))))
    (for-each
      test-combination
      (genlist () arg-types))))

;($define! type-error-messages (list "Invalid argument."))
;($type-test $if #:boolean #:any #:any)
($define! type-error-messages (list "Invalid argument."))
($type-test symbol->string #:symbol)
($type-test string->symbol #:string)
($type-test error #:string)

($define! type-error-messages
  (list "Invalid argument."
        "Cannot traverse list structure."))
($type-test car #:pair)
($type-test cdr #:pair)
($type-test set-car! #:pair #:any)
($type-test set-cdr! #:pair #:any)

($define! type-error-messages (list "Expected environment argument(s)."))
($type-test eval #:any #:environment)

($define! type-error-messages (list "Invalid argument."))
($type-test wrap #:combiner/applicative)
($type-test unwrap #:combiner/applicative)
($type-test apply #:combiner/applicative #:any)
($type-test apply #:combiner/applicative #:any #:environment)

($type-test extend-continuation #:continuation #:combiner/applicative)
($type-test extend-continuation #:continuation #:combiner/applicative #:environment)

($define! type-error-messages
  (list "Invalid argument."
        "Invalid guard list."
        "Invalid continuation guard specification."))
($type-test guard-continuation #:pair #:continuation #:pair)
($type-test guard-dynamic-extent #:pair #:combiner/applicative #:pair)

($define! type-error-messages (list "Expected numeric argument(s)."))
($type-test + #:number #:number)
($type-test - #:number #:number)
($type-test * #:number #:number)
($type-test negate #:number)

;; Type errors in deep arguments of guard-dynamic-extent.
;;
($define! $test-guard-dynamic-extent
  ($vau (args (msg irritants)) denv
    ($define! symbol ($quote guard-dynamic-extent))
    ($define! (en comb ex) (eval (cons list args) denv))
    (check-error
      (list (list unwrap symbol)
            en
            comb
            ex)
      (list (list msg)
            (eval irritants denv)
            symbol))))

($test-guard-dynamic-extent
  ((list #t) ($lambda () ()) ())
  ("Invalid continuation guard specification." #t))
($test-guard-dynamic-extent
  (() ($lambda () ()) (list #f))
  ("Invalid continuation guard specification." #f))
($test-guard-dynamic-extent
  (()
   ($lambda () ())
   (list (list error-continuation ($lambda () ()))
         (list 2345)))
  ("Invalid continuation guard specification." (list 2345)))
($test-guard-dynamic-extent
  (()
   ($lambda () ())
   (list (list 3456 ($lambda () ()))))
  ("Invalid continuation guard selector." 3456))
($test-guard-dynamic-extent
  (()
   ($lambda () ())
   (list (list error-continuation 4567)))
  ("Invalid continuation guard interceptor." 4567))
($test-guard-dynamic-extent
  (() 1234 ())
  ("Invalid argument." 1234))

;; Invalid structure in $let bindings
;;

($define! $test-binding-structure
  ($vau (let-symbol . bindings) denv
    (check-error
      (list let-symbol bindings)
      (list (list "Invalid argument structure.")
            bindings
            let-symbol))))

($test-binding-structure $let (0))
($test-binding-structure $let (x 1 2 3))
($test-binding-structure $let (x 1) (y 2 3))
($test-binding-structure $let* (#ignore))
($test-binding-structure $let* (x 1 2))
($test-binding-structure $letrec (#ignore #ignore #ignore))
($test-binding-structure $letrec (x 1 2))
($test-binding-structure $letrec* (x . y))
($test-binding-structure $letrec* (x 1) (y 2) (z 3 4))
($test-binding-structure $bindings->environment (a 1 2) (b 3 4))
($test-binding-structure $bindings->environment () () ())

;; Invalid structure in non-standard operatives
;;

($define! $test-non-standard
  ($vau (invalid-form messages irritant) denv
    (check-error
      invalid-form
      (list messages irritant #ignore))))

($test-non-standard ($let1) ("Invalid argument structure.") ())
($test-non-standard ($let1 x) ("Invalid argument structure.") ())
($test-non-standard ($let1 x 1) ("Invalid argument structure.") (x 1))
($test-non-standard (hash-table-ref 2 3) ("Internal error.") 2)
($test-non-standard (write-u8 4 5) ("Invalid argument.") 5)
($test-non-standard (bytevector-copy-partial 1 2 3) ("Invalid argument.") 1)

(summary)
