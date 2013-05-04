;;;
;;; signals.asm
;;;
;;; Signal handling features, assembly part.
;;;

;;
;; app_signal_setup (continuation passing procedure)
;;
;; Implementation of (signal-setup SIGNO MODE), where
;; SIGNO is a signal number and MODE is
;;
;;  #t - to enable handling by lisp (signal-handler) combiner
;;  #f - to set default signal action
;;  #ignore - to ignore the signal
;;
app_signal_setup:
  .A2:
    mov eax, ebx
    xor al, 3
    test al, 1
    jne .error
    cmp ebx, fixint_value(1)
    jl .error
    cmp ebx, fixint_value(64)
    jg .error
    xchg ebx, ecx
    cmp bl, boolean_value(0)
    je .args_ok
    cmp bl, ignore_tag
    je .args_ok
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_signal_setup)
    jmp rn_error
  .args_ok:
    xchg ebx, ecx
    call rn_signal_setup
    mov eax, inert_tag
    jmp [ebp + cont.program]

;;
;; app_read_signal (continuation passing procedure)
;;
;; Implementation of private combiner (read-signal),
;; which returns
;;
;;   - signal number 
;;   - eof-object
;;   - #ignore
;;
op_read_signal:
    call rn_sigring_read
    jmp [ebp + cont.program]
