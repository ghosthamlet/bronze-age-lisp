;;;
;;; bss.asm
;;;
;;; Declaration of uninitialized global variables and heaps.
;;;

    align 4

;; global variables
;;
stack_limit             resd 1
transient_limit         resd 1
lisp_heap_pointer       resd 1
first_blob              resd 1
free_blob               resd 1
rn_error_active         resd 1

last_combination        resd 1
last_combiner           resd 1
last_ptree              resd 1

;; buffer
;;
platform_info           resb 256

;; auxilliary buffer
;;
scratchpad_start        resb 256
scratchpad_end:

;; space for lisp and blob heaps
;;
lisp_heap_area:
    resb (4 * configured_lisp_heap_size + configured_blob_heap_size)
lisp_heap_area_end:
