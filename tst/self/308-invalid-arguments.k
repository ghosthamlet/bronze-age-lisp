;;;
;;; 308-invalid-arguments.k
;;;
;;; Test error handling in build-in combiners.
;;;

($define! check-error
  ($lambda (expr error-info)
    ($let*
      (((msg irritants source) error-info)
       (a (protect-eval expr
                        (make-kernel-standard-environment)))
       (b (cons "error" error-info))
       (ok ($and? (equal? (car a) "error")
                  (equal? (cadr a) msg)
                  (equal? (caddr a) irritants)
                  ($if (ignore? source) #t (equal? (cadddr a) source)))))
      ($if ok
        (pass)
        (fail-with-report msg expr a b)))))

;; Most combiners signal an error, if the parameter tree
;; is not a list (the only exception is the non-standard
;; operative $quote*)
;;
($define! $nonlist-test
  ($vau symbols #ignore
    ($define! test-pair
      ($lambda (symbol nonlist)
        ($let ((msg "Invalid argument structure."))
          (check-error (cons symbol nonlist)
                       (list msg nonlist symbol))
        #| test also the underlying operative ?
          ($when (applicative? (eval symbol (make-kernel-standard-environment)))
            (check-error (cons (list ($quote unwrap) symbol)
                               nonlist)
                         (list msg nonlist #ignore)))
         |#
                         )))
    (for-each
      ($lambda (arg)
        (for-each ($lambda (sym) (test-pair sym arg)) symbols))
      (list #t #f #inert #ignore 0 -1 1
            (make-environment)))))

($nonlist-test
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
  ;make-keyed-static-variable
  number? integer? finite?
    =? <? >? <=? >=?
    + - *
    zero? positive? negative?
    div mod div-and-mod
    abs max min
    string->number number->string
    ; lcm gcd expt
    ;div0 mod0 div-and-mod0
    ; u8?
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
    ; read-line
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
        ($let ((msg "Invalid argument structure."))
          (check-error (cons symbol arglist)
                       (list msg arglist symbol)))))
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
  
($narg-test 2 2
  cons set-car! set-cdr!
  assoc assq member? memq?
  ;TODO
  )

($narg-test 3 3 $if)
($narg-test 1 #e+infinity $when $unless)
($narg-test 2 #e+infinity map for-each)


(summary)
