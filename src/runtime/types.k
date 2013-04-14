;;;
;;; types.k
;;;
;;; Definition of type tags and headers for the interpreter.
;;;
;;;     bit 31 (msb)                     bit 0 (lsb)
;;;     |                                |
;;; (A) 00pppppp pppppppp pppppppp pppp000   pointer
;;; (B) nnnnnnnn nnnnnnnn nnnnnnnn nnnnn01   30-bit fixint
;;; (C) vvvvvvvv vvvvvvvv vvvvvvvv ttttt10   24-bit immediate value
;;; (D) 00qqqqqq qqqqqqqq qqqqqqqq qqqqq11   immutable pair
;;; (E) 10qqqqqq qqqqqqqq qqqqqqqq qqqqq11   mutable pair
;;; (F) 00nnnnnn nnnnnnnn nnnnnnnn ttttt01   header word
;;;
;;; (A) 00pppppp pppppppp pppppppp ppppp00   object backpointer
;;; (A) 01qqqqqq qqqqqqqq qqqqqqqq qqqqq11   pair backpointer
;;; (A) 11qqqqqq qqqqqqqq qqqqqqqq qqqqq11   pair backpointer

($define! immediate-types
  ($quote*
    (#b00000010 "nil")
    (#b00000110 "inert")
    (#b00001010 "ignore")
    (#b00001110 "eof")

    (#b00010010 "primitive")    ; primitive operative
    (#b00010110 "unbound") ; "value" of unbound dynamic variable

    (#b00100010 "symbol")
    (#b00100110 "keyword")
    (#b00101010 "string")
    (#b00101110 "bytevector")

    ;; N.B. highest two bits of char tag must be 01
    (#b01000010 "char")
    (#b01000110 "boolean")
    (#b01001010 "einf")))   ; exact infinity (payload is +/-1)

($define! header-types
  ($quote*
    ;; top two bits of vector and environment tag must be zero!
    (#b00000001 "vector" () "element")
    (#b00000101 "encapsulation" ("class") "var")
    (#b00001001 "error" ("message" "irritants" "source" "cc" "address"))
    (#b00001101 "critbit" ("index" "child0" "child1"))

    ;; N.B. common bits in the tags, see predicates.k
    (#b00010001 "operative" ("program") "var")
    (#b00010101 "applicative" ("program" "underlying") "var")
    (#b00011001 "cont" ("program" "parent") "var")
    (#b00011101 "environment" ("program" "parent") "key" "val")

    ;; N.B. common bits in the tags, see predicates.k
    (#b00100001 "txt-in" ("env" "close" "read" "peek")  "var")
    (#b00100101 "txt-out" ("env" "close" "write" "flush") "var")
    (#b00101001 "bin-in" ("env" "close" "read" "peek") "var")
    (#b00101101 "bin-out" ("env" "close" "write" "flush") "var")

    ;; top two bits of bigint header tag must be zero
    (#b00110001 "bigint" () "digit")
    (#b00110101 "promise" ("node"))
    ))

;;
;; range of fixints
;;
($define! max-fixint 536870911)
($define! min-fixint -536870912)

;;
;; Representation of assembler constant and expressions.
;;

($define! (encapsulate-immediate-value immediate-value? immediate-value-repr)
  (make-encapsulation-type))

;;
;; for each tagged type, define
;;
;;  type-tag          tag corresponding to the type
;;
;; for each type with header, define
;;
;;  type-header-tag   lower 8 bits of the header word
;;  type-header       header word for default size
;;  (type-header* N)  header word for N-word object (inc. header)
;;

(eval
  (cons
    $sequence
    (map
      ($lambda ((tag name . rest))
        (list $define! (symbol-append* name "-tag") tag))
      immediate-types))
  (get-current-environment))

(eval
  (cons
    $sequence
    (map
      ($lambda ((tag name . #ignore))
        (list $define! (symbol-append* name "-header-tag") tag))
      header-types))
  (get-current-environment))

(eval
  (cons
    $sequence
    (map
      ($lambda ((tag name lead-members . tail-members))
        (cons $define!
          ($if (null? tail-members)
            (list
              (symbol-append* name "-header")
              (encapsulate-immediate-value
                (+ tag (* 256 (+ 1 (length lead-members))))))
            (list
              (symbol-append* name "-header*")
              ($lambda (n)
                (encapsulate-immediate-value (+ tag (* 256 n))))))))
      header-types))
  (get-current-environment))

;;
;; (emit-type-macros)
;;
;; Prints macro definitions which depend on the type tags.
;;
($provide! (emit-type-macros)

  ($define! program-tags
    (list primitive-tag))

  ($define! emit-tags
    ($lambda ()
      (for-each
        ($lambda ((tag name))
          ($define! name (asm-identifier name))
          (asm (string-append* name "_tag") "equ" tag)
          (asm "%define" (string-append* name "_value(x)")
            "((("
            ($if (member? tag program-tags)
              "(x) - program_segment_base"
              "x")
            ") << 8) | " tag ")"))
       immediate-types)))

  ($define! emit-struc
    ($lambda (name fields opts)
      (asm "struc" name)
      (asm " " ".header" "resd 1")
      (for-each
        ($lambda (f) (asm " " (string-append* "." f) "resd 1"))
        fields)
      ($for (i 0 5)
        (for-each
          ($lambda (f)
            (asm " " (string-append* "." f i) "resd 1"))
          opts))
      (asm "endstruc")))

  ($define! emit-header-macros
    ($lambda ()
      (for-each
        ($lambda ((tag name lead . tail))
          ($define! name (asm-identifier name))
          ($if (null? tail)
            (asm "%define" (string-append* name "_header")
              (+ tag (* 256 (+ 1 (length lead)))))
            (asm "%define" (string-append* name "_header(n)")
               "(" "((n) << 8) | " tag ")"))
          (emit-struc name lead tail))
        header-types)))

  ($define! emit-type-macros
    ($lambda ()
      (asm)
      (asm ";; fixint range")
      (asm "%define max_fixint" max-fixint)
      (asm "%define min_fixint" min-fixint)
      (asm)
      (asm ";; type tags and structure of heap-allocated objects")
      (emit-tags)
      (asm)
      (emit-header-macros)
      (asm))))

;;
;; Representation of non-lisp values, fixints and immediate lisp
;; values.
;;
($provide!
  (pack pack-fixint
   pad-list pad-list-even pad-list-odd
   make-nonlisp-value
   make-lisp-fixint make-tagged-value make-lisp-blob
   make-primitive-operative)

  ($define! make-nonlisp-value
    ($lambda args
      (encapsulate-immediate-value (apply string-append* args))))

  ($define! pack-fixint
    ($lambda (x)
      ($define! u
        ($cond
          ((<=? 0 x max-fixint) x)
          ((<=? min-fixint x -1) (- x min-fixint min-fixint))
          (#t (error "cannot represent as fixint" x))))
      (string-append "0x" (number->string (+ 1 (* 4 u)) 16))))

  ($define! pack
    ($lambda (tag val)
      ($cond
        (($and? (integer? val) (<=? 0 val #x00FFFFFF))
          (+ tag (* 256 val)))
        ((string? val)
          (string-append* tag "| ((" val ") << 8)"))
        (#t
          (error "value does not fit in tagged word" tag val)))))

  ($define! make-lisp-fixint
    ($lambda (x)
      ($cond
        ((integer? x)
          (encapsulate-immediate-value (pack-fixint x)))
        ((string? x)
          (string-append* fixint-tag "| ((" x ") << 2)"))
        (#t
          (error "cannot represent as fixint" x)))))

  ($define! make-tagged-value
    ($lambda (tag val)
      (encapsulate-immediate-value (pack tag val))))

  ($define! pad-list
    ($lambda (n xs)
      ($if (zero? (mod (+ n (length xs)) 2))
        xs
        (append xs (list 0)))))

  ($define! pad-list-even ($lambda (xs) (pad-list 0 xs)))
  ($define! pad-list-odd  ($lambda (xs) (pad-list 1 xs)))

  ($define! make-lisp-blob
    ($lambda (tag index)
      ($unless (<=? 1 index ($configured blob-descriptor-capacity))
        (error "invalid blob index" index))
      (make-tagged-value tag index)))

  ($define! make-primitive-operative
    ($lambda label-cs
      (make-tagged-value primitive-tag
        (string-append*
          (apply string-append* label-cs)
          " - program_segment_base")))))

;;
;; Representation of structured lisp values, which will
;; be placed in read-only segments of the interpreter.
;;
($provide!
  (make-standard-port
   make-builtin-continuation
   make-operative
   make-rom-object rom-object? rom-object-set-field! rom-object-fields)

  ($define! (encapsulate-rom-object rom-object? rom-object-fields)
    (make-encapsulation-type))

  ($define! make-rom-object
    ($lambda args
      (encapsulate-rom-object args)))

  ($define! rom-object-set-field!
    ($lambda (rom-obj index new-value)
      (set-car!
        (list-tail (rom-object-fields rom-obj) index)
        new-value)))

  ($define! make-standard-port
    ($lambda (header* filedes close-method io-method flush-method)
      (make-rom-object
        (header* 5)
        filedes
        (make-primitive-operative close-method)
        (make-primitive-operative io-method)
        (make-primitive-operative flush-method))))

  ($define! make-builtin-continuation
    ($lambda (program-label parent)
      (make-rom-object
        (cont-header* 3)
        (make-nonlisp-value program-label)
        parent)))

  ($define! make-operative
    ($lambda (program-label . rest)
      ($define! rest (pad-list-even rest))
      (apply make-rom-object
        (list*
          (operative-header* (+ 2 (length rest)))
          (make-nonlisp-value program-label)
          rest)))))
