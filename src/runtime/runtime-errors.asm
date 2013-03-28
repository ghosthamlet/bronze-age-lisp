;;;
;;; runtime-errors.asm
;;;
;;; Error handling.
;;;

;;
;; rn_error
;;
;; Error handler for use in native procedures.
;;
;; preconditions: EAX = error message (lisp string)
;;                EBX = irritant (lisp object)
;;                ECX = procedure which detected the error (lisp symbol)
;;               [ESP] = caller address
;;
rn_error:
    mov edx, [rn_error_active]
    test edx, edx
    jnz .double
    mov [rn_error_active], dword 1
    push ecx
    push ebx
    push eax
    mov ecx, (error_header >> 8)
    call rn_allocate
    mov ecx, eax
    mov [ecx + error.header], dword error_header
    pop dword [ecx + error.message]
    pop dword [ecx + error.irritants]
    pop dword [ecx + error.source]
    mov [ecx + error.cc], ebp
    pop eax
   ; sub eax, program_segment_base
    lea eax, [4*eax + 1]
    mov [ecx + error.address], eax
    mov ebx, error_continuation
    mov esp, [stack_limit]
    mov [rn_error_active], dword 0
    jmp rn_apply_continuation
  .double:
    jmp rn_fatal
