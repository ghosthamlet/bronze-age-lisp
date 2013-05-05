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
backup_cc_address       resd 1
backup_cc_count         resd 1
last_combination        resd 1
last_combiner           resd 1
last_ptree              resd 1

;; buffer
;;
platform_info           resb 256

;; ring buffer of signals caught by native code but
;; not yet processed by lisp code
;;
struc sigring_element
  .signo resd 1
endstruc
sigring_initialized     resd 1
sigring_wp              resd 1
sigring_rp              resd 1
sigring_overflow        resd 1
sigring_buffer          resd (configured_signal_ring_capacity * sigring_element_size)

;; buffer for performance statistics
;;
perf_time_buffer        resd (perf_time_section_count * 8)

;; auxilliary buffer
;;
scratchpad_start        resb 256
scratchpad_end:

;; space for lisp and blob heaps
;;
lisp_heap_area:
    resb (4 * configured_lisp_heap_size + configured_blob_heap_size)
lisp_heap_area_end:

;; space for signal stack
;;
signal_stack_base:      resb 8192
signal_stack_limit:
