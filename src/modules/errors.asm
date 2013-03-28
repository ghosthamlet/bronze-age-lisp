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
  .On:
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    jmp .throw

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
    jmp [ebp + cont.program]

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
