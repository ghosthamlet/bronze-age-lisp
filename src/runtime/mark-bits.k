;;;
;;; mark-bits.k
;;;

;; one slot for
;;  - each 8 bytes of heap
;;  - each string
;;  - each 8 bytes of read-only data

($define! emit-mark-bit-macros
  ($lambda (rodata-size)
    ($define! rom-slots  (div rodata-size 8))
    ($define! heap-slots (div ($configured lisp-heap-size) 8))
    ($define! blob-slots ($configured blob-descriptor-capacity))
    ($define! reserved-slots 1)
    ($define! all-slots  (align (+ reserved-slots rom-slots heap-slots blob-slots) 8))
    ($define! mark-space (align (+ (* 5 all-slots) (div (+ all-slots 7) 8)) 8))
    ($unless (<=? mark-space ($configured lisp-heap-size))
      (error "Mark words do not fit in heap halfspace. Configured heap size is too small."
        (list mark-space ($configured lisp-heap-size))
        (list rom-slots heap-slots blob-slots reserved-slots)
        all-slots))
    (asm "rom_mark_slots  equ" rom-slots)
    (asm "heap_mark_slots equ" heap-slots)
    (asm "blob_mark_slots equ" blob-slots)
    (asm "all_mark_slots  equ" all-slots)))
