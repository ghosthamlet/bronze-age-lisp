;;;
;;; lists.asm
;;;
;;; High-level list manipulation procedures.
;;;

app_assoc:
  .A2:
    ;; ebx = first arg = key
    ;; ecx = second arg = list
    ;; ebp = continuation
    push ebx
    push ecx
    mov ebx, ecx
    call rn_list_metrics
    test eax, eax
    jz .invalid_list
    mov ecx, edx
    pop esi
    pop edx
    jecxz .not_found
  .next_element:
    mov ebx, car(esi)
    call rn_pairP_procz
    jne .invalid_element
    mov ebx, car(ebx)
    push ecx
    mov ecx, edx
    call rn_equal
    pop ecx
    test eax, eax
    jnz .found
    mov esi, cdr(esi)
    loop .next_element
  .not_found:
    mov eax, nil_tag
    jmp [ebp + cont.program]
  .found:
    mov eax, car(esi)
    jmp [ebp + cont.program]
  .invalid_list:
    pop ebx
    pop eax
  .invalid_element:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_assoc)
    jmp rn_error

app_memqP:
  .A2:
    ;; ebx = first arg = key
    ;; ecx = second arg = list
    ;; ebp = continuation
    push ebx
    push ecx
    mov ebx, ecx
    call rn_list_metrics
    test eax, eax
    jz .invalid_list
    mov ecx, edx
    pop esi
    pop edx
    jecxz .not_found
    dec ecx
    cmp edx, car(esi)
    je .found
    jecxz .not_found
  .next:
    mov esi, cdr(esi)
    cmp edx, car(esi)
    je .found
    loop .next
  .not_found:
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
  .found:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .invalid_list:
    pop ebx
    pop eax
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_memqP)
    jmp rn_error
