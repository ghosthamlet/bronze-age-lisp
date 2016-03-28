;;;
;;; promises.asm
;;;
;;; Promise (lazy evaluation) features, assembler part.
;;;
;;; The implementation follows the derivation in the Kernel Report,
;;; and also the klisp implementation. The promise object contains
;;; one field "node", which references a pair (OBJECT . ENV).
;;;

;;
;; aux_allocate_promise (continuation passing procedure)
;;
;; preconditions: EBX = object (CAR field of the promise)
;;                EDI = environment or nil (CDR field of the promise)
;;

app_memoize:
  .A1:
    instrumentation_point
    mov edi, nil_tag
  .allocate_promise:
    mov ecx, 4
    call rn_allocate
    lea ecx, [eax + 8]
    shr ecx, 1
    or  ecx, 0x80000003
    mov [eax + promise.header], dword promise_header
    mov [eax + promise.node], ecx
    mov [eax + 8], ebx
    mov [eax + 12], edi
    jmp [ebp + cont.program]

primop_Slazy:
    instrumentation_point
    test bl, 3
    jz .error
    jnp .error
    mov eax, cdr(ebx)
    cmp eax, nil_tag
    jne .error
    mov ebx, car(ebx)
    mov eax, edi               ; capture dynamic environment
    call rn_capture
    jmp app_memoize.allocate_promise
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Slazy)
    jmp rn_error

app_promise_ref:
  .A1:
    instrumentation_point
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp eax, promise_header
    jne .error
    mov eax, [ebx + promise.node]
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_promise_ref)
    jmp rn_error

app_promise_setB:
  .A2:
    instrumentation_point
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp eax, promise_header
    jne .error
    mov [ebx + promise.node], ecx
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_promise_setB)
    jmp rn_error
