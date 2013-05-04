;;;
;;; configuration.k
;;;
;;; Configuration parameters and their default values.
;;;
;;;

($provide! (configuration configuration-help)

  ($define! configuration (make-environment))

  ($define-add! configuration-help () cons)

  ($define! $param
    ($vau (name value help) denv
      (set! configuration name (eval value denv))
      (configuration-help-add! (list name value help))))

  ($param blob-heap-size (* 16 1024)
    "Size of blob heap (bytes).")
  ($param blob-descriptor-capacity 1024
    "Size of blob heap descriptor table (entries).")
  ($param lisp-heap-size (* 128 1024)
    "Size of lisp heap (bytes, power of two).")
  ($param lisp-transient-size (* 8 1024)
    "Size of transient environment area in the heap (bytes).")
  ($param lisp-heap-threshold (* 9 1024)
    "Allocation threshold (bytes).")

  ($param stdio #t
    "Enable ports and standard input/output/error ports.")
  ($param raw-stdio #f
    "Binary input/output/error ports.")
  ($param default-buffer-size 256
    "Default buffer size for textual ports.")
  ($param reader-and-printer #t
    "Enable (read), (write).")
  ($param character-predicates #t
    "Enable (char-alphabetic?).")

  ($param signal-ring-capacity 16
    "Capacity of ring buffer for information on caught signals.")

  ($param debug-evaluator #f
    "Enables debugging messages in the evaluator.")
  ($param debug-gc-cycle #f
    "Enables debugging message about free heap after GC cycle.")
  ($param debug-gc-detail #f
    "Enables detailed debugging messages in the garbage collector.")
  ($param debug-gc-blobs #f
    "Enables debugging messages blob GC.")
  ($param debug-environments #f
    "Enables debugging messages in environments.")
  ($param debug-ports #f
    "Enables debugging messages in the ports module.")
  ($param debug-continuations #f
    "Enables debugging messages in continuations.")

  ($param no-data-segment #f
    "Do not output data segments (testing only).")
  ($param no-code-segment #f
    "Do not output code segment (testing only).")
  ($param no-macros #f
    "Do not output assembler macros and constants (testing only).")
  ($param no-applicative-support #f
    "Do not generate applicative support code (testing only).")

  ($param asm-prefix ""
    "Path to assembler sources of the interpreter (relative to working directory of NASM)")
  ($param src-prefix ""
    "Path to lisp sources of the interpreter (relative to working directory of mold.k)")

  ($param user-ground-bindings ()
    "Additional ground bindings")

  ($param start-form ($quote (stand-alone-interpreter))
     "Object evaluated after the interpreter starts up."))

;;
;; ($configured P)
;;
;; Returns the value of the configuration parameter P.
;;
($define! $configured
  ($vau (sym) #ignore (eval sym configuration)))

;;
;; (check-configuration)
;;
;; Halts the program if the configuration is not valid.
;;
($provide! (check-configuration)

  ($define! power-of-two?
    ($lambda (x)
      ($cond
        ((<=? x 0) #f)
        ((=? x 1)  #t)
        (#t        ($let (((q r) (div-and-mod x 2)))
                     ($and? (=? r 0) (power-of-two? q)))))))

  ($define! check-configuration
    ($lambda ()
      ($unless (power-of-two? ($configured lisp-heap-size))
        (error "lisp-heap-size must be power of two"))
      ($unless (<? ($configured lisp-transient-size)
                   ($configured lisp-heap-threshold))
        (error "allocation threshold is too small"))
      ($unless (<=? 64 ($configured lisp-transient-size))
        (error "transient size is too small"))
      ($unless (=? 0 (mod ($configured lisp-transient-size) 8))
        (error "transient size is not a multiple of 8"))
      ($unless
        (>=? (- ($configured lisp-heap-size)
                ($configured lisp-transient-size)
                ($configured lisp-heap-threshold))
             256)
        (error "lisp heap is too small"))
      ($unless ($and? (<=? 2 ($configured signal-ring-capacity) 256)
                      (power-of-two? ($configured signal-ring-capacity)))
        (error "signal-ring-capacity must be a power of two in the range 2..256"))
      ($when ($configured reader-and-printer)
        ($unless ($configured character-predicates)
          (error "reader depends on character predicates")))
)))
