;;;
;;; applicatives.k
;;;

;;
;; (emit-applicative-dispatch)
;;   Print assembler code supporting applicatives created
;;   by (make-asm-applicative ...).
;;
;; (make-bounded-applicative A B LABELS CLOSED-VARIABLES)
;;   Creates representation of applicative and its underlying
;;   operative, which takes at least A and at most B arguments,
;;   implemented by assembler procedures listed in LABELS,
;;
;;    LABELS = (L[A] L[A+1] ... L[B-1] L[B])
;;
;;  The list CLOSED-VARIABLES is appended at the end of
;;  the operative object.
;;
;;    applicative object = [ applicative_header(?)
;;                           rn_asm_applicative.LAB
;;                           <operative object>
;;                           L[A]
;;                           L[A+1]
;;                           ...
;;                           L[B] ]
;;
;;    operative object   = [ operative_header(?)
;;                           rn_asm_operative.LAB
;;                           L[A]
;;                           L[A+1]
;;                           ...
;;                           L[B]
;;                           CLOSED-VARIABLES... ]
;;
;; (make-unbounded-applicative A B LABELS OPERATIVE)
;;   Creates representation of (wrap OPERATIVE). Moreover,
;;   the calls with at least A and at most B arguments are
;;   re-implemented by assembler procedures listed in LABELS.
;;
;;    applicative object = [ applicative_header(?)
;;                           rn_asm_applicative.LABx
;;                           <operative object>
;;                           L[A]
;;                           L[A+1]
;;                           ...
;;                           L[B] ]
;;
;; (emit-bounded-applicative-constructors)
;;
;;   Print assembly code to create an applicatives like
;;   the ones created by (make-bounded-applicative)
;;   for 1, 2 and 3 arguments.
;;

($provide! (emit-applicative-support
            make-bounded-applicative
            make-unbounded-applicative)

  ($define! label-prefix ".L")

  ($define! label
    ($lambda components
      (apply string-append* (cons label-prefix components))))

  ($define! argument-register-alist
    ($quote* (0 . "ebx") (1 . "ecx") (2 . "edx")))

  ($define! argument-register
    ($lambda (index)
      ($let ((v (assoc index argument-register-alist)))
        ($when (null? v)
          (error "argument-register" index))
        (cdr v))))

  ($define! cont-slot
    ($lambda (register index)
      ($unless (<=? 0 index)
        (error "cont-slot" register index))
      (string-append* "[" register " + cont.var0 + "
                      (+ 8 (* 4 index)) "]")))

  ($define! cont-env
    ($lambda (register)
      (string-append* "[" register " + cont.var0]")))

  ($define! cont-combiner
    ($lambda (register)
      (string-append* "[" register " + cont.var0 + 4]")))

  ($define! app-handler
    ($lambda (register index)
      (string-append* "[" register " + applicative.var0 + "
                      (* 4 index) "]")))

  ($define! ope-handler
    ($lambda (register index)
      (string-append* "[" register " + operative.var0 + "
                      (* 4 index) "]")))

  ($define-add! emited-applicative-instance-labels () cons)

  ($define! emit-unbounded-applicative-instance
    ($lambda ((a b))
      ($unless (<=? 0 a b (length argument-register-alist))
        (error "emit-unbounded-applicative-instance" a b))
      (asm-label (label a b "x"))
      (asm "mov esi, eax")
      (asm "push ebx")
      (asm "call rn_list_metrics")
      (asm "pop ebx")
      (asm "test eax, eax")
      (asm "jz rn_generic_applicative.with_list_metrics")
      (asm "test ecx, ecx")
      (asm "jnz rn_generic_applicative.with_list_metrics")
      (asm "mov eax, esi")
      ($for (n a b)
        (asm "cmp edx," n)
        (asm "je " (label a "c" n)))
      (asm "jmp rn_generic_applicative.with_list_metrics")
      (asm)))

  ($define! emit-bounded-applicative-instance
    ($lambda ((a b))
      ($unless (<=? 0 a b (length argument-register-alist))
        (error "emit-bounded-applicative-instance" a b))
      (asm-label (label a b))
      (asm "call rn_count_parameters")
      ($for (n a b)
        (asm "cmp ecx," n)
        (asm "je " (label a "c" n)))
      (asm "jmp .error")
      ($for (n a b)
        ($unless (member? (list a n) emited-applicative-instance-labels)
          (emited-applicative-instance-labels-add! (list a n))
        ($when (=? n 0)
          (asm-label (label a "c" n))
          (asm "mov edx, " (app-handler "eax" (- n a)))
          (asm "mov eax, [eax + applicative.underlying]")
          (asm "mov esi, eax")
          (asm "jmp edx"))
        ($when (>? n 0)
          ;; prepare continuation and evaluate the first argument
          (asm-label (label a "c" n))
          ($let* ((m  (+ 5 (- n 1)))
                  (m1 (align m 2)))
            (asm "mov edx, cdr(ebx)")
            (asm "mov ebx, car(ebx)")
            (asm "mov esi, eax")
            (asm "mov ecx, " (- 0 m1))
            (asm "call rn_allocate_transient")
            (asm "xchg esi, eax")
            (asm "mov [esi + cont.header], dword" (immediate-value-repr (cont-header* m1)))
            (asm "mov [esi + cont.program], dword" (label a "c" n 1))
            (asm "mov [esi + cont.parent], ebp")
            (asm "mov" (cont-env "esi") ", edi")
            (asm "mov" (cont-combiner "esi") ", eax")
            ($for (i 0 (- n 2))
              (asm "mov ecx, car(edx)")
              ($when (<? i (- n 2))
                (asm "mov edx, cdr(edx)"))
              (asm "mov" (cont-slot "esi" i) ", ecx"))
            ($when (<? m m1)
              (asm "mov" (cont-slot "esi" (- n 1)) ", ecx ; pad"))
            (asm "mov ebp, esi")
            (asm "jmp rn_eval"))
          ;; continuation for each argument
          ($for (i 1 (- n 1))
            ($let ((s (- i 1)))
              (asm-label (label a "c" n i))
              (asm "call rn_force_transient_continuation")
              (asm "mov edi, " (cont-env "ebp"))
              (asm "mov ebx, " (cont-slot "ebp" s))
              (asm "mov" (cont-slot "ebp" s) ", eax")
              (asm "mov [ebp + cont.program], dword "
                (label a "c" n (+ i 1)))
              (asm "jmp rn_eval")))
          ;; last continuation
          (asm-label (label a "c" n n))
          (asm "mov " (argument-register (- n 1)) ", eax")
          ($for (k 0 (- n 2))
            (asm "mov " (argument-register k) ","
                 (cont-slot "ebp" k)))
          (asm "mov eax," (cont-combiner "ebp"))
          (asm "mov edi," (cont-env "ebp"))
          (asm "mov ebp, [ebp + cont.parent]")
          ($if (<? n (length argument-register-alist))
            ($let ((tmp (argument-register n)))
              (asm "mov " tmp "," (app-handler "eax" (- n a)))
              (asm "mov eax, [eax + applicative.underlying]")
              (asm "mov esi, eax")
              (asm "jmp " tmp))
            ($sequence
              (asm "push dword " (app-handler "eax" (- n a)))
              (asm "mov eax, [eax + applicative.underlying]")
              (asm "mov esi, eax")
              (asm "ret")))
          (asm))))))

  ($define-add! emited-operative-instance-labels () cons)

  ($define! emit-operative-instance
    ($lambda ((a b))
      (asm-label (label a b))
      (asm "call rn_count_parameters")
      ($for (n a b)
        (asm "cmp ecx," n)
        (asm "je " (label a "c" n)))
      (asm "jmp .error")
      ($for (n a b)
        ($unless (member? (list a n) emited-operative-instance-labels)
          (emited-operative-instance-labels-add! (list a n))
          (asm-label (label a "c" n))
          ($cond
            ((=? n 0)
              #inert)
            ((=? n 1)
              (asm "mov ebx, car(ebx)"))
            (#t
              ($let ((q (argument-register (- n 1))))
                (asm "mov " q ", ebx")
                ($for (i 0 (- n 2))
                  (asm "mov " (argument-register i) ", car(" q ")")
                  (asm "mov " q ", cdr(" q ")"))
                (asm "mov " q ", car(" q ")"))))
          (asm "jmp" (ope-handler "eax" (- n a)))
          (asm)))))

  ($define! emit-error-handler
    ($lambda ()
      (asm-label ".error")
      (asm "mov ecx, eax")
      (asm "mov eax, err_invalid_argument_structure")
      (asm "jmp rn_error")))

  ($define! emit-applicative-support
    ($lambda ()
      ($let ((cases-b ($quote* (0 0) (0 1) (1 1) (0 2) (1 2) (2 2) (2 3) (0 3) (1 3) (3 3)))
             (cases-u ($quote* (0 1) (0 2) (2 2) (0 3) (2 3))))
        (asm-label "rn_asm_applicative")
        (for-each emit-bounded-applicative-instance cases-b)
        (for-each emit-unbounded-applicative-instance cases-u)
        (emit-error-handler)
        (asm)
        (asm)
        (asm-label "rn_asm_operative")
        (for-each emit-operative-instance cases-b)
        (emit-error-handler))
      (emit-bounded-applicative-constructors)))

  ($define! make-bounded-applicative
    ($lambda ((a b) labels-ab closed-variables)
      ($define! nvar (length closed-variables))
      ($define! nlbl (+ 1 (- b a)))
      ($unless (=? nlbl (length labels-ab))
        (error "make-bounded-applicative"
          (list a b)
          labels-ab))
      ($define! padded-variables (pad-list (+ 2 nlbl) closed-variables))
      ($define! padded-labels (pad-list-odd labels-ab))
      ($define! lower
        (apply make-rom-object
          (append
            (list
              (operative-header* (+ 2 nlbl (length closed-variables)))
              (make-nonlisp-value "rn_asm_operative" (label a b)))
            (map make-nonlisp-value labels-ab)
            padded-variables)))
      ($define! upper
        (apply make-rom-object
          (list*
            (applicative-header* (+ 3 (length padded-labels)))
            (make-nonlisp-value "rn_asm_applicative" (label a b))
            lower
            (map make-nonlisp-value padded-labels))))
      upper))

  ($define! make-unbounded-applicative
    ($lambda ((a b) labels-ab underlying)
      ($define! labels-ab (pad-list-odd labels-ab))
      (apply make-rom-object
        (list*
          (applicative-header* (+ 3 (length labels-ab)))
          (make-nonlisp-value "rn_asm_applicative" (label a b "x"))
          underlying
          (map make-nonlisp-value labels-ab)))))

  ($define! emit-bounded-applicative-constructor
    ($lambda (n)
      (asm)
      (asm-label (string-append* "make_bounded_applicative_" n))
      ;; Assume
      ;;   EBX = formal ptree (S1 S2 .. Sn), where Sk are symbols
      ;;   EDX = procedure body
      ;;   EDI = the static environment
      ;; Create the equivalent of ($lambda (S1 ... SN) . BODY).
      ;;
      ($define! app-sz 4)
      ($define! op-sz (align (+ n 5) 2))
      ($define! symbol-slot ($lambda (k) (* 4 (+ 5 k))))
      (asm "mov eax, edi")
      (asm "call rn_capture")
      (asm "mov ecx, " (+ app-sz op-sz))
      (asm "call rn_allocate")
      (asm "lea ecx, [eax + 16]")
      (asm "mov [eax], dword applicative_header(4)")
      (asm "mov [eax +  4], dword" (string-append* "rn_asm_applicative.L" n n))
      (asm "mov [eax +  8], ecx")
      (asm "mov [eax + 12], dword .execute")
      (asm "mov [ecx], dword operative_header(" op-sz ")")
      (asm "mov [ecx +  4], dword" (string-append* "rn_asm_operative.L" n n))
      (asm "mov [ecx +  8], dword .execute")
      (asm "mov [ecx + 12], edi")
      (asm "mov [ecx + 16], edx")
      ($for (k 0 (- n 1))
        (asm "mov edx, car(ebx)")
        ($unless (=? k (- n 1)) (asm "mov ebx, cdr(ebx)"))
        (asm "mov [ecx + " (symbol-slot k) "], edx"))
      ($when (=? 0 (mod n 2))
        (asm "mov [ecx + " (symbol-slot n) "], dword inert_tag"))
      (asm "jmp [ebp + cont.program]")

      (asm-label ".execute")
      ($for (k 0 (- n 1))
        (asm "push" (cdr (assoc (- n 1 k) argument-register-alist))))
      (asm "mov ecx, " (* 6 n))
      (asm "call rn_allocate")
      (asm "mov edi, [esi + 12]")
      ($for (k 0 (- n 1))
        (asm "mov [eax + environment.header], dword environment_header(6)")
        ($let ((p ($if (zero? k) "tail_env_lookup" "list_env_lookup")))
          (asm "mov [eax + environment.program], dword" p))
        (asm "mov [eax + environment.parent], edi")
        (asm "mov ebx, [esi +" (symbol-slot k) "]")
        (asm "pop ecx")
        (asm "mov [eax + environment.key0], ebx")
        (asm "mov [eax + environment.val0], ecx")
        (asm "mov [eax + environment.key1], ecx")
        (asm "mov edi, eax")
        (asm "lea eax, [eax + 24]"))
      (asm "mov ebx, [esi + 16]")
      (asm "jmp rn_sequence")))

  ($define! emit-bounded-applicative-constructors
    ($lambda ()
      (for-each emit-bounded-applicative-constructor
        (list 1 2 3)))))

($provide!
  (make-builtin-wrap make-builtin-lambda
   $define-ground-lambda! $define-private-lambda!
   $define-ground-wrapvau! $define-private-wrapvau!
   $define-ground-vau! $define-private-vau!
   $defun-privates!)

  ($define! private-env-object
    (make-nonlisp-value "private_env_object"))

  ($define! make-builtin-wrap
    ($let ((label (make-nonlisp-value "rn_generic_applicative")))
      ($lambda (underlying)
        (make-rom-object
          (applicative-header* 4)
          label
          underlying
          0))))

  ($define! make-builtin-lambda
    ($lambda (name formals body)
      ($if ($and? (finite-list? formals)
                  (<=? 1 (length formals) 3)
                  (apply symbol? formals))
        (make-interpreted-bounded-applicative name formals body)
        (make-ordinary-builtin-lambda name formals body))))

  ($define! make-ordinary-builtin-lambda
    ($lambda (name formals body)
      (make-builtin-wrap
        (make-rom-object
          (operative-header* 8)
          (make-nonlisp-value "operate_interpreted.noenv")
          private-env-object
          formals
          #ignore
          body
          name
          0))))

  ($define! make-builtin-vau
    ($lambda (name formals eformal body)
      (make-rom-object
        (operative-header* 8)
        (make-nonlisp-value "operate_interpreted.env")
        private-env-object
        formals
        eformal
        body
        name
        0)))

  ($define! make-builtin-wrapvau
    ($lambda (name formals eformal body)
      (make-builtin-wrap
        (make-rom-object
          (operative-header* 8)
          (make-nonlisp-value "operate_interpreted.env")
          private-env-object
          formals
          eformal
          body
          name
          0))))

  ($define! make-interpreted-bounded-applicative
    ($lambda (name formals body)
      ($define! n (length formals))
      ($unless ($and? (<=? 1 n 3) (apply symbol? formals))
        (error "make-interpreted-bounded-applicative"
          name formals n))
      (make-bounded-applicative
        (list n n)
        (list (string-append* "make_bounded_applicative_" n ".execute"))
        (list* private-env-object
               body
               formals))))

  ($define! $define-ground-lambda!
    ($vau (name formals . body) #ignore
      (bind-ground! name (make-builtin-lambda name formals body))))

  ($define! $define-ground-vau!
    ($vau (name formals eformal . body) #ignore
      (bind-ground! name (make-builtin-vau name formals eformal body))))

  ($define! $define-private-lambda!
    ($vau (name formals . body) #ignore
      (bind-private! name (make-builtin-lambda name formals body))))

  ($define! $define-private-vau!
    ($vau (name formals eformal . body) #ignore
      (bind-private! name (make-builtin-vau name formals eformal body))))

  ($define! $define-ground-wrapvau!
    ($vau (name formals eformal . body) #ignore
      (bind-ground! name
        (make-builtin-wrapvau name formals eformal body))))

  ($define! $define-private-wrapvau!
    ($vau (name formals eformal . body) #ignore
      (bind-private! name
        (make-builtin-wrapvau name formals eformal body))))

  ($define! $defun-privates!
    ($vau labels #ignore
      (for-each
        ($lambda ((name formals . body))
          (bind-private! name
            (make-builtin-lambda name formals body)))
        labels)))
)
