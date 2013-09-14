;;;
;;; primitives.k
;;;
;;; Bindings for the ground and private environment.
;;;
($letrec*
  (($prim-op
     ($vau symbols #ignore
       (for-each
         ($lambda (s)
           (bind-ground! s
             (make-primitive-operative "primop_" (asm-identifier s))))
         symbols)))
   ($prim-app
     ($vau symbols #ignore
       (for-each
         ($lambda (s)
           (bind-ground! s
             (make-builtin-wrap
               (make-primitive-operative "app_" (asm-identifier s) ".operate"))))
         symbols)))
   (genlist
     ($lambda (a b suffix)
       ($if (<=? a b)
         (cons
           (string-append* "app_" suffix ".A" a)
           (genlist (+ a 1) b suffix))
         ())))
   ($bounded-app
     ($vau (a b . symbols) #ignore
       (for-each
         ($lambda (s)
           (bind-ground! s
             (make-bounded-applicative
               (list a b) (genlist a b (asm-identifier s)) ())))
         symbols)))
   ($unbounded-app
     ($vau (a b . symbols) #ignore
       (for-each
         ($lambda (x)
           ($let
             (((s t) ($if (symbol? x)
                      (list x (asm-identifier x))
                      x)))
             (bind-ground! s
               (make-unbounded-applicative
                 (list a b)
                 (genlist a b t)
                 (make-primitive-operative
                   "app_" t ".operate")))))
         symbols))))
  ($prim-op
    $quote $quote* $let1
    $sequence $when $unless $if $cond
    $and? $or?
    $define! $set! $binds?
    $let $letrec $let* $let-redirect $let-safe $match
    $vau $lambda
    $lazy
    $let/cc)
  ($prim-app
    bytevector-copy-partial!)
  ($bounded-app 0 0
    get-current-environment
    make-kernel-standard-environment
    make-encapsulation-type
    make-keyed-dynamic-variable
    make-keyed-static-variable
    get-interpreter-arguments
    rdtsc get-current-second
    get-current-jiffy get-jiffies-per-second
    collect-garbage
    getpid)
  ($bounded-app 0 1
    exit
    open-output-string
    open-output-bytevector
    open-binary-pipe)
  ($bounded-app 0 2
    waitpid)
  ($bounded-app 1 1
    not?
    negate
    get-list-metrics length
    string-length string-size
    vector-length bytevector-length
    wrap unwrap
    reverse
    copy-es-immutable
    bytevector-copy
    get-output-string
    get-output-bytevector get-output-bytevector-position
    char->integer integer->char
    open-utf-decoder
    open-input-string
    string->symbol symbol->string string->keyword keyword->string symbol->keyword keyword->symbol
    error-object-message error-object-irritants error-object-source error-object-continuation
    open-binary-input-file open-binary-output-file
    make-keyed-dynamic-variable*
    continuation->applicative
    memoize
    get-library-export-list get-library-environment
    integer-length bitwise-not
    shared-structure-indicator
    delete-file)
  ($bounded-app 1 2
    char-digit? char->digit digit->char
    open-utf-encoder
    make-vector make-bytevector
    fork)
  ($bounded-app 1 3
    execve)
  ($bounded-app 2 2
    cons eval
    list-tail list-ref
    set-car! set-cdr!
    string-ref vector-ref bytevector-u8-ref
    div mod div-and-mod
    arithmetic-shift
    apply-continuation
    dup2)
  ($bounded-app 2 3
    apply extend-continuation)
  ($bounded-app 3 3
    encycle!
    guard-continuation guard-dynamic-extent
    set! vector-set! bytevector-u8-set!
    bytevector-copy-partial)
  ($unbounded-app 2 3
    (- "minus"))
  ($unbounded-app 0 3
    (+ "plus") (* "times")
    bitwise-and bitwise-ior)
  ($unbounded-app 0 1
    error string-append)
  ($unbounded-app 0 2
    make-environment append)
  ($unbounded-app 2 2
    map for-each)
  ($unbounded-app 0 3
    and? or? list))

;;
;; private function (guess-object-name OBJECT TRY-HARDER),
;; where OBJECT is arbitrary lisp value and TRY-HARDER
;; is a boolean.
;;
(bind-ground! ($quote guess-object-name) ;TODO: bind-private!
  (make-bounded-applicative
    (list 2 2)
    (list "app_guess_object_name.A2")
    ()))

;;
;; Make the private environment available for built-in
;; lisp code.
;;
($bind-private! private-environment
  (make-nonlisp-value "private_env_object"))

;;
;; Slot for lazily initialized tree of interned symbol.
;;
($bind-private! intern ())


;;
;; add buffering layer on top of the binary I/O ports
;; TODO: replace with keyed variables
;;
($when ($configured stdio)
  ($let
    (($bind-io!
       ($vau (symbol procedure nargs port-header-tag variable) denv
         ($define! port-header-tag (eval port-header-tag denv))
         ($define! variable (eval variable denv))
         (bind-ground! symbol
           (make-bounded-applicative
             (list (apply min nargs) (apply max nargs))
             (map ($lambda (n) (string-append* procedure ".A" n)) nargs)
             (list symbol port-header-tag variable))))))
    ($bind-io! write-char "app_write_typed" (1 2)
               txt-out-header-tag char-tag)
    ($bind-io! write-string "app_write_typed" (1 2)
               txt-out-header-tag string-tag)
    ($bind-io! write-bytevector "app_write_typed" (1 2)
               bin-out-header-tag bytevector-tag)
    ($bind-io! write-utf8-string "app_write_typed" (1 2)
               bin-out-header-tag string-tag)
    ($bind-io! write-utf8-char "app_write_typed" (1 2)
               bin-out-header-tag char-tag)
    ($bind-ground! write-u8
      (make-bounded-applicative
        (list 1 2)
        (list "app_write_u8.A1" "app_write_u8.A2")
        ()))

    ($bind-io! read-char "app_read_typed" (0 1)
               txt-in-header-tag 3)
    ($bind-io! peek-char "app_read_typed" (0 1)
               txt-in-header-tag 4)
    ($bind-io! read-bytevector "app_read_typed" (0 1)
               bin-in-header-tag 3)

    ($bind-ground! flush-output-port
      (make-bounded-applicative
        (list 0 1)
        (list "app_flush_output_port.A0" "app_flush_output_port.A1")
        ()))

    ($bind-io! close-port "app_close_typed" (1) txt-in-header-tag #b11110011)
    ($bind-io! close-input-port "app_close_typed" (1) txt-in-header-tag #b11110111)
    ($bind-io! close-output-port "app_close_typed" (1) txt-out-header-tag #b11110111))

  ($define-ground-lambda! open-input-file (s)
    (open-utf-decoder (open-binary-input-file s)))
  ($define-ground-lambda! open-output-file (s)
    (open-utf-encoder (open-binary-output-file s)))

  ($bind-ground! get-textual-input-position
    (make-bounded-applicative
      (list 0 1)
      (list "app_get_textual_input_position.A0" "app_get_textual_input_position.A1")
      ()))

  ($unless ($configured raw-stdio)
    (init-forms-add!
      ($quote
        ($sequence
          ($define! stdin (open-utf-decoder stdin))
          ($define! stdout (open-utf-encoder stdout))
          ($define! stderr (open-utf-encoder stderr)))))))
