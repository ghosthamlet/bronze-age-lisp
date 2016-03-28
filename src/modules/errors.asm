;;;
;;; errors.asm
;;;

app_error:
  .A0:
    instrumentation_point
    mov eax, string_value(rom_string_error)
    mov ebx, nil_tag
    jmp .throw
  .A1:
    instrumentation_point
    mov eax, ebx
    mov ebx, nil_tag
  .throw:
    cmp al, string_tag
    jne .fail_eax
    mov ecx, symbol_value(rom_string_error)
    jmp rn_error
  .An:
  .operate:
    test ebx, 3
    jz .fail
    jnp .fail
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    jmp .throw
  .fail_eax:
    mov ebx, eax
  .fail:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_error)
    jmp rn_error

app_make_error_object:
  .A1:
    instrumentation_point
    mov ecx, nil_tag
  .A2:
    instrumentation_point
    mov edx, inert_tag
  .A3:
    instrumentation_point
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
    mov [eax + error.env], dword inert_tag
    mov [eax + error.pad], dword inert_tag
    jmp [ebp + cont.program]

app_error_object_message:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_error_object_message)
    call check_error_object
    mov eax, [ebx + error.message]
    jmp [ebp + cont.program]

app_error_object_irritants:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_error_object_irritants)
    call check_error_object
    mov eax, [ebx + error.irritants]
    jmp [ebp + cont.program]

app_error_object_source:
  .A1:
    instrumentation_point
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
    instrumentation_point
    mov esi, symbol_value(rom_string_error_object_continuation)
    call check_error_object
    mov eax, [ebx + error.cc]
    jmp [ebp + cont.program]

app_error_object_environment:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_error_object_environment)
    call check_error_object
    mov eax, [ebx + error.env]
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
    instrumentation_point
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

;;
;; Implementation of private combiner
;;
;;   (deconstruct-environment ENV) => #:ground
;;                                    #:private
;;                                    #:multiparent
;;                                    (PARENT-ENV (SYM . VAL) ...)
;;
app_deconstruct_environment:
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_deconstruct_environment)
    jmp rn_error
  .A1:
    instrumentation_point
    test bl, 3
    jnz .error
    cmp byte [ebx], environment_header(0)
    jne .error
    mov edi, ebx
    mov esi, nil_tag
  .iter:
    cmp [edi + environment.program], dword tail_env_lookup
    je .list_or_tail
    cmp [edi + environment.program], dword list_env_lookup
    je .list_or_tail
    cmp edi, dword ground_env_object
    je .ground
    cmp [edi + environment.program], dword multiparent_env_lookup
    je .multiparent
  .private:
    mov eax, keyword_value(rom_string_private)
    jmp [ebp + cont.program]
  .ground:
    mov eax, keyword_value(rom_string_ground)
    jmp [ebp + cont.program]
  .multiparent:
    mov eax, keyword_value(rom_string_multiparent)
    jmp [ebp + cont.program]
  .list_or_tail:
    mov ebx, [edi + environment.key0]
    mov ecx, [edi + environment.val0]
    push ebx
    push ecx
    call rn_cons
    push eax
    push esi
    call rn_cons
    mov esi, eax
    cmp [edi + environment.program], dword list_env_lookup
    jne .tail
  .next:
    mov edi, [edi + environment.parent]
    jmp .iter
  .tail:
    push dword [edi + environment.parent]
    push esi
    call rn_cons
    jmp [ebp + cont.program]
