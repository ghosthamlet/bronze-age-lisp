;;;
;;; misc.asm
;;;
;;; Non-standard operatives.
;;;

primop_SquoteX:
    mov eax, ebx
    jmp [ebp + cont.program]

primop_Squote:
    test bl, 3
    jz .error
    jnp .error
    mov eax, cdr(ebx)
    cmp al, nil_tag
    jne .error
    mov eax, car(ebx)
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Squote)
    jmp rn_error

app_undef:
    mov eax, err_invalid_argument_structure
    mov ebx, dword nil_tag
    mov ecx, inert_tag
    jmp rn_error

primop_no_op:
    mov eax, inert_tag
    jmp [ebp + cont.program]

primop_true:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
