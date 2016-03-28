;;;
;;; libraries.asm
;;;
;;; Klisp-compatible library system, assembly part.
;;;

app_make_library_object:
  .A1:
    instrumentation_point
    mov ecx, 2
    call rn_allocate
    mov [eax + library.header], dword library_header
    mov [eax + library.env], ebx
    jmp [ebp + cont.program]

app_get_library_export_list:
  .A1:
    instrumentation_point
    test bl, 3
    jnz .error
    cmp [ebx], dword library_header
    jne .error
    mov esi, nil_tag
    mov edi, [ebx + library.env]
    cmp [edi + environment.program], dword list_env_lookup
    jne .done
  .next_binding:
    push dword [edi + environment.key0]
    push esi
    call rn_cons
    mov esi, eax
    mov edi, [edi + environment.parent]
    cmp [edi + environment.program], dword list_env_lookup
    je .next_binding
  .done:
    mov eax, esi
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_library_export_list)
    jmp rn_error

app_get_library_environment:
  .A1:
    instrumentation_point
    test bl, 3
    jnz .error
    cmp [ebx], dword library_header
    jne .error
    mov ebx, [ebx + library.env]
    call rn_make_list_environment
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_library_environment)
    jmp rn_error
