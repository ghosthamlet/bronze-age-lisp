;;;
;;; errors.asm
;;;

app_error:
  .A0:
    mov eax, string_value(rom_string_error)
    mov ebx, nil_tag
    jmp .throw
  .A1:
    mov eax, ebx
    mov ebx, nil_tag
  .throw:
    mov ecx, symbol_value(rom_string_error)
    jmp rn_error
  .An:
  .operate:
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    jmp .throw

app_make_error_object:
  .A1:
    mov ecx, nil_tag
  .A2:
    mov edx, inert_tag
  .A3:
    cmp bl, string_tag
    jne .invalid_argument
    cmp dl, symbol_tag
    je .ok
    cmp dl, inert_tag
    je .ok
    mov ebx, edx
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_make_error_object)
    jmp rn_error
  .ok:
    mov esi, ecx
    mov ecx, (error_header >> 8)
    call rn_allocate
    mov [eax + error.header], dword error_header
    mov [eax + error.message], ebx
    mov [eax + error.irritants], esi
    mov [eax + error.source], edx
    mov ecx, error_continuation
    mov [eax + error.cc], ecx
    jmp [ebp + cont.program]

app_error_object_message:
  .A1:
    mov esi, symbol_value(rom_string_error_object_message)
    call check_error_object
    mov eax, [ebx + error.message]
    jmp [ebp + cont.program]

app_error_object_irritants:
  .A1:
    mov esi, symbol_value(rom_string_error_object_irritants)
    call check_error_object
    mov eax, [ebx + error.irritants]
    jmp [ebp + cont.program]

app_error_object_source:
  .A1:
    mov esi, symbol_value(rom_string_error_object_source)
    call check_error_object
    mov eax, [ebx + error.source]
    cmp al, primitive_tag
    jmp .guess
    test al, 3
    jz .guess
  .done:
    jmp [ebp + cont.program]
  .guess:
    mov ebx, eax
    call rn_guess_name
    cmp al, symbol_tag
    je .done
    mov eax, ebx
    jmp .done

app_error_object_continuation:
  .A1:
    mov esi, symbol_value(rom_string_error_object_continuation)
    call check_error_object
    mov eax, [ebx + error.cc]
    jmp [ebp + cont.program]

check_error_object:
    test bl, 3
    jnz .fail
    mov eax, [ebx]
    cmp eax, error_header
    jne .fail
    ret
  .fail:
    mov eax, err_invalid_argument
    mov ecx, esi
    jmp rn_error

app_guess_object_name:
  .A2:
    push ebx
    call rn_guess_name
    pop ebx
    cmp al, symbol_tag
    je .done
    cmp ecx, boolean_value(1)
    jne .done
    ;; TODO: try harder, scan the whole heap!
  .done:
    jmp [ebp + cont.program]
