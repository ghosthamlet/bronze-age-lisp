;;;
;;; native-interfaces.k
;;;
;;; Support for runtime machine code generators.
;;;

;;
;; Store addresses of assembly code labels in the private environment.
;;
(for-each
  ($lambda (sym)
    (bind-private! sym (make-nonlisp-value sym)))
  ($quote*
    rn_cons
    rn_eval
    rn_combine
    rn_error
    rn_allocate
    rn_allocate_transient
    rn_get_blob_data
    rn_mutate_environment
    rn_make_list_environment
    rn_eq
    app_plus.add_two_numbers
    app_minus.subtract_two_numbers
    app_times.multiply_two_numbers
    app_write_typed.unsafe_io))

;;
;; Define combiner objects for helpers implemented in assembly.
;;
;;  (fixed-binding-address SYMBOL) => INTEGER
;;  (vector->operative! VECTOR) => #inert
;;  (operative->vector COMBINER) => VECTOR
;;
(for-each
  ($lambda (sym)
    (bind-private! sym
      (make-bounded-applicative
        (list 1 1)
        (list (string-append* "app_" (asm-identifier sym) ".A1"))
        ())))
  ($quote* fixed-binding-address vector->operative! operative->vector))

;;
;; Compiler of an simple low-level imperative programs to native code.
;; This compiler is intended to serve as a back end of another compiler
;; in the future.
;;
;; The programs may call interpreter primitives. The parameters and
;; results of the subroutines are passed in the accumulator register EAX
;; (denoted by #:acc) and local variables (denoted by integers) stored
;; in an continuation object. The control flow constructs resemble
;; continuation passing style. The commands of the program contain a
;; reference the following command(s).
;;
;; The programs P obey the following grammar
;;
;;   program   P = (#:store V P-cont)
;;               | (#:load V P-cont)
;;               | (#:if T P-consequent P-alternative)
;;               | (#:return)
;;               | (#:primitive F (V1 ... Vn) P-cont)
;;
;;   variable  V = #:acc                  -- the accumulator register EAX
;;               | <integer>              -- local varible
;;               | (#:quote OBJECT [UID]) -- any object (stored in closure)
;;               | (#:standard EXPR)      -- result of evaluation in std. env
;;
;;   test      T = #:pair     -- test if EAX contains a pair
;;               | ()         -- test if EAX is the nil value ()
;;               | 0          -- test if EAX contains zero fixint
;;               | #t         -- test if EAX contains #t
;;               | #f         -- test if EAX contains #f
;;               | #:eof      -- test if EAX contains the eof-object
;;
;;   primitive F = #:cons
;;                 #:car
;;                 #:cdr
;;                 #:combine  (combiner ptree env)
;;                 #:io       (port value) -- read or write method of a port
;;                 #:+ #:- #:*
;;                 #:eq
;;
;; There are no code labels, but the program may be cyclic, for example
;;
;;    #1=(#:if #:pair
;;         (#:primitive cdr (#:acc) #1#)
;;         (#:return))
;;
;; The compiler is invoked through the combiner
;;
;; (make-compiled-operative FORMAL EFORMAL PROGRAM) => OPERATIVE
;;
;; Where FORMAL (and EFORMAL, respectively) is either an integer
;; denoting a local variable, or #ignore. FORMAL and EFORMAL
;; must not be the same integers. When the resulting operative
;; is invoked, the parameter tree is stored in FORMAL and the dynamic
;; environment is stored in EFORMAL.
;;

($define-ground-lambda! make-compiled-operative (formal eformal program)
  ($when (integer? formal)
    ($define! program (list #:store-register formal #:ebx program)))
  ($when (integer? eformal)
    ($define! program (list #:store-register eformal #:edi program)))
  ($define! (ntemp closure-list bytevector) (ni-compile program))
  ($define! closure (list->vector (list* #ignore bytevector 0 ntemp closure-list)))
  (vector->operative! closure)
  closure)

;;
;; (disassemble-compiled-combiner COMBINER) => #inert
;;
;; Print disassebmled native code of COMBINER.  The underlying operative
;; of COMBINER must have been created by make-compiled-operative.
;;
;; Uses ndisassm command line utility (from NASM package). The utility
;; must be installed in $PATH.
;;

($define-ground-lambda! disassemble-compiled-combiner (x)
  ($define! v (operative->vector x))
  (format #t ";; code size (bytes)   ... ~d~%" (bytevector-length (vector-ref v 1)))
  (format #t ";; entry point offset  ... ~d~%" (vector-ref v 2))
  (format #t ";; temporaries (slots) ... ~d~%" (vector-ref v 3))
  (format #t ";; closure (slots)     ... ~d~%" (- (vector-length v) 4))
  ($with-subshell "ndisasm -b32 -"
    ((binary-stdin f))
    (write-bytevector (vector-ref v 1) f))
  #inert)

($define-ground-lambda! ni-compile (the-program)
  ($define! labels ())
  ($define! offset 0)
  ($define! buffer ())
  ($define! targets ())
  ($define! max-local -1)
  ($define! closure-list ())
  ($define! closure-size 0)
  ($define! env (get-current-environment))
  ($define! note-local
    ($lambda (r)
      ($when (integer? r)
        ($set! env max-local (max max-local r)))))
  ($define! closure-offset
    ($lambda (x-id)
      ($match (assq x-id closure-list)
        ((#ignore . index) index)
        (() ($define! index closure-size)
            ($set! env closure-size (+ closure-size 1))
            ($set! env closure-list (cons (cons x-id index) closure-list))
            (* 4 (+ 5 index))))))
  ($define! bytes
    ($lambda data
      ($set! env offset (+ offset (length data)))
      ($set! env buffer (cons data buffer))))
  ($define! dwords
    ($lambda data
      (apply bytes (apply append (map dword->bytes data)))))
  ($define! dword-placeholder
    ($lambda ()
      ($set! env offset (+ offset 4))
      ($define! tmp (cons #inert buffer))
      ($set! env buffer tmp)
      ($lambda (v) (set-car! tmp (dword->bytes v)))))
  ($define! new-label
    ($lambda args
      ($set! env labels (cons args labels))))
  ($define! reserve-label
    ($lambda (prog)
      ($match (assoc prog labels)
        ((#ignore #:placed target-offset)
          (list #:placed target-offset))
        ((#ignore #:reserved . tail)
          (list #:reserved ($lambda (f) (set-car! tail (cons f (car tail))))))
        (#ignore
          ($define! tail (list ()))
          (apply new-label (list* prog #:reserved tail))
          (list #:reserved ($lambda (f) (set-car! tail (cons f (car tail)))))))))
  ($define! place
    ($lambda (prog . rest)
      ($match (assoc prog labels)
        ((#ignore #:placed target-offset)
          ($when (equal? rest ())
            ($cond
              ((equal? prog (list #:return))
                (code prog))
              (#t
                ;; jmp <32-bit relative>
                (bytes #xE9)
                (dwords (- target-offset (+ offset 4)))))))
        ((#ignore #:reserved fixers)
          (for-each ($lambda (f) (f offset)) fixers)
          (set-cdr! (assoc prog labels) (list #:placed offset))
          (code prog))
        (#ignore
          (new-label prog #:placed offset)
          (code prog)))))
  ($define! code
    ($case-lambda
      (((#:return))
        ;; mov ebp, [ebp + cont.parent]
        ;; jmp DWORD PTR [ebp + cont.program]
        (bytes #x8B #x6D #x08
                #xFF #x65 #x04))
      (((#:store r pcont))
        ;; mov DWORD PTR [ebp + offset], eax
        (note-local r)
        (bytes #x89 #x45 (local-variable-offset r))
        (place pcont))
      (((#:load v pcont))
        (ni-code-mov #:eax v)
        (place pcont))
      (((#:store-register var reg pcont))
        (note-local var)
        ($match reg
          (#:ebx (bytes #x89 #x5D (local-variable-offset var)))
          (#:edi (bytes #x89 #x7D (local-variable-offset var)))
          (#ignore
            (error "invalid register for #:store-register command" reg)))
        (place pcont))
      (((#:primitive prim args pcont))
        (for-each note-local args)
        ($if (member? prim ni-cps-primitives)
          ($cond
            ((equal? pcont (list #:return))
              ;; mov ebp, [ebp + cont.parent]
              (ni-code-primitive prim args
                ($lambda () (bytes #x8B #x6D #x08))))
            (#t
              ($match (reserve-label pcont)
                ((#:reserved add-fixup)
                  ;; mov [ebp + 16], <placeholder>
                  (bytes #xC7 #x45 16)
                  ($define! fixup-dword (dword-placeholder))
                  (add-fixup ($lambda (offset) (fixup-dword (fixint->dword offset))))
                  (ni-code-primitive prim args $sequence)
                  (place pcont #f))
                ((#:placed offset)
                  ;; mov [ebp + 16], fixint_value(offset)
                  (bytes #xC7 #x45 16)
                  (dwords (fixint->dword offset))
                  (ni-code-primitive prim args $sequence)))))
          ($sequence
            (ni-code-primitive prim args)
            (place pcont))))
      (((#:if test t1 t2))
        (ni-code-test test)
        ($match (list (reserve-label t1) (reserve-label t2))
          (((#:reserved f1) (#:reserved f2))
            ;; jne <32-bit relative offset>
            (bytes #x0F #x85)
            ($define! fixup-dword (dword-placeholder))
            ($define! jump-base offset)
            (f2 ($lambda (v) (fixup-dword (- v jump-base))))
            (place t1)
            (place t2 #f))
          (((#:placed target) (#:reserved f2))
            ;; je <32-bit offset>
            (bytes #x0F #x84)
            (dwords (- target (+ 4 offset)))
            (place t2))
          (((#:reserved f1) (#:placed target))
            ;; jne <32-bit offset>
            (bytes #x0F #x85)
            (dwords (- target (+ 4 offset)))
            (place t1))
          (((#:placed target-1) (#:placed target-2))
            ;; je <32-bit offset>
            ;; jmp <32-bit offset>
            (bytes #x0F #x84)
            (dwords (- target-1 (+ 4 offset)))
            (bytes #xE9)
            (dwords (- target-2 (+ 4 offset))))
          (x
            (error "Error when compiling #:if" x))))
      (prog
        (error "Invalid imperative program" prog))))
  (place the-program)
  (list
    (+ 1 (bitwise-and (+ 1 max-local) -2))
    (reverse (map caar closure-list))
    (nested-lists->bytevector (reverse buffer) offset)))

($define-private-lambda! local-variable-offset (r)
  (* 4 (+ 5 r)))

($define-private-lambda! fixint->dword (x)
  (+ (* 4 x) 1))

($define-private-lambda! dword->bytes (x)
  (map
    ($lambda (p) (bitwise-and (arithmetic-shift x p) #xFF))
    ($quote* 0 -8 -16 -24)))

($define-private-lambda! nested-lists->bytevector (lists size)
  ($define! bytes (make-bytevector size))
  ($define! walk
    ($case-lambda
      ((() n)
        n)
      (((x . xs) n)
        (walk xs (walk x n)))
      ((x n)
        (bytevector-u8-set! bytes n x)
        (+ n 1))))
  (walk lists 0)
  bytes)

;;
;; code generator helpers
;;

($define-private-vau! $ni-code-interpreter (convention symbol) denv
  ($import! denv bytes dwords)
  (bytes #x3E #xFF
         ($match convention
           (#:call #x15)     ; call DWORD PTR ds:<address>
           (#:jump #x25)))   ; jmp  DWORD PTR ds:<address>
  (dwords (fixed-binding-address symbol)))

($define-private-wrapvau! ni-code-mov (reg val) denv
  ($import! denv bytes closure-offset)
  ($match val
    ;; mov REG, EAX
    (#:acc
      ($unless (eq? reg #:eax)
        (bytes #x89
               ($match reg (#:ebx #xC3) (#:ecx #xC1) (#:edi #xC7)))))
    ;; mov REG, [ESI + offset]
    ((#:quote . vt)
      (bytes #x8B
             ($match reg (#:eax #x46) (#:ebx #x5E)
                         (#:ecx #x4E) (#:edi #x7E))
             (closure-offset vt)))
    ((#:standard x)
      (ni-code-mov
        reg
        (list #:quote (eval x (make-kernel-standard-environment)))))
    ;; mov REG, [EBP + offset]
    (i
      ($unless (integer? i)
        (error "cannot generate mov instruction" reg i))
      (bytes #x8B
        ($match reg (#:eax #x45) (#:ebx #x5D) (#:ecx #x4D) (#:edi #x7D))
        (local-variable-offset i)))))

($define-private-wrapvau! ni-code-push (val) denv
  ($import! denv bytes closure-offset)
  ($match val
    ;; push EAX
    (#:acc
      (bytes #x50))
    ;; push [ESI + offset]
    ((#:quote . vt)
      (bytes #xFF #x76 (closure-offset vt)))
    ;; push [EBP + offset]
    (i
      (bytes #xFF #x75 (local-variable-offset i)))))

($define-private-wrapvau! ni-code-test (t) denv
  ($import! denv bytes dwords)
  ($cond
    ((eq? t #t)
      ;; cmp eax, boolean_value(1)
      (bytes #x3D)
      (dwords #b101000110))
    ((eq? t 0)
      (bytes #x3D)
      (dwords 1))
    ((eq? t #:eof)
      (bytes #x3D)
      (dwords #b00001110))
    ((eq? t #:pair)
      ;; test al, 3
      ;; sete cl
      ;; setnp ch
      ;; test cx, cx
      (bytes #xA8 #x03
              #x0F #x94 #xC1
              #x0F #x9B #xC5
              #x66 #x85 #xC9))
    (#t
      (error "Invalid test for #:if command" t))))

;;
;; primitives
;;

($bind-private! ni-cps-primitives
  ($quote* #:eval #:combine #:error #:io))

($define-private-wrapvau! ni-code-primitive args denv
  ($import! denv bytes dwords closure-offset)
  ($match args
    ((#:car (v))
      (ni-code-mov #:eax v)
      (bytes #x8B #x44 #x00 #xFA))
    ((#:cdr (v))
      (ni-code-mov #:eax v)
      (bytes #x8B #x44 #x00 #xFE))
    ((#:cons (v1 v2))
      (ni-code-push v1)
      (ni-code-push v2)
      ($ni-code-interpreter #:call rn_cons))
    ((#:set (e s v))
      (ni-code-mov #:ebx v)
      (ni-code-mov #:edi e)
      (ni-code-mov #:eax s)
      ($ni-code-interpreter #:call rn_mutate_environment))
    ((#:make-environment (e))
      (ni-code-mov #:ebx e)
      ($ni-code-interpreter #:call rn_make_list_environment))
    ((#:io (p v) code-continuation-fix)
      (ni-code-mov #:ebx p)
      (ni-code-mov #:ecx v)
      (code-continuation-fix)
      ($ni-code-interpreter #:jump app_write_typed.unsafe_io))
    ((#:eval (v1 v2) code-continuation-fix)
      (ni-code-mov #:ebx v1)
      (ni-code-mov #:edi v2)
      (code-continuation-fix)
      ($ni-code-interpreter #:jump rn_eval))
    ((#:error (v1 v2 v3) code-continuation-fix)
      (ni-code-mov #:ebx v2)
      (ni-code-mov #:ecx v3)
      (ni-code-mov #:eax v1)
      (code-continuation-fix)
      ($ni-code-interpreter #:jump rn_error))
    ((#:combine (v1 v2 v3) code-continuation-fix)
      (ni-code-mov #:ebx v2)
      (ni-code-mov #:edi v3)
      (ni-code-mov #:eax v1)
      (code-continuation-fix)
      ($ni-code-interpreter #:jump rn_combine))
    ((#:+ (v1 v2))
      (ni-code-mov #:ebx v1)
      (ni-code-mov #:ecx v2)
      ($ni-code-interpreter #:call app_plus.add_two_numbers))
    ((#:- (v1 v2))
      (ni-code-mov #:ebx v1)
      (ni-code-mov #:ecx v2)
      ($ni-code-interpreter #:call app_minus.subtract_two_numbers))
    ((#:* (v1 v2))
      (ni-code-mov #:ebx v1)
      (ni-code-mov #:ecx v2)
      ($ni-code-interpreter #:call app_times.multiply_two_numbers))
    ((#:eq (v1 v2))
      (ni-code-mov #:ebx v1)
      (ni-code-mov #:ecx v2)
      ($ni-code-interpreter #:call rn_eq)
      ;; mov ah, al
      ;; mov al, boolean_tag
      (bytes #x88 #xC4
             #xB0 #x46))
    ((#:list xs)
      (error "TODO primitive (list)"))
    (cmd
      (error "invalid #:primitive command" args))))
