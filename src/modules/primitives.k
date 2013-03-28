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
           (bind-ground! s (make-primitive-operative "primop_" s)))
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
                 (make-primitive-operative "primop_SquoteX")))))
         symbols))))
  ($prim-op
    $quote $quote*
    $sequence $when $unless $if $cond
    $and? $or?
    $define! $set! $let1
    $vau $lambda
    $let/cc)
  ($bounded-app 0 0
    get-current-environment
    make-kernel-standard-environment
    open-output-string
    get-interpreter-arguments)
  ($bounded-app 1 1
    not?
    length ;string-length
    wrap unwrap
    get-output-string
    char->integer integer->char
    open-utf-encoder open-utf-decoder
    open-input-string
    string->symbol symbol->string keyword->string
    error-object-message error-object-irritants error-object-source error-object-continuation
    open-binary-input-file open-binary-output-file)
  ($bounded-app 1 2
    char-digit? char->digit)
  ($bounded-app 2 2
    cons eval
    assoc memq?
    div mod div-and-mod
    apply-continuation)
  ($bounded-app 3 3
    guard-continuation guard-dynamic-extent)
  ($unbounded-app 2 3
    (- "minus"))
  ($unbounded-app 0 3
    (+ "plus") (* "times"))
  ($unbounded-app 0 1
    error)
  ($unbounded-app 0 3
    list))

;;
;; Table for assembler implementation of (number->string ...).
;;
(rodata-extra-add!
  ($lambda ()
    (asm "hex_digits: db \"0123456789ABCDEF\"")))

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
    ($bind-io! write-utf8 "app_write_typed" (1 2)
               bin-out-header-tag string-tag)

    ($bind-io! read-char "app_read_typed" (0 1)
               txt-in-header-tag 3)
    ($bind-io! peek-char "app_read_typed" (0 1)
               txt-in-header-tag 4)

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

  ($unless ($configured raw-stdio)
    (init-forms-add!
      ($quote
        ($sequence
          ($define! stdin (open-utf-decoder stdin))
          ($define! stdout (open-utf-encoder stdout))
          ($define! stderr (open-utf-encoder stderr)))))))
