;;;
;;; symbols.asm
;;;
;;; Built-in applicatives related to symbols and keywords.
;;;

app_string_Gsymbol:
  .A1:
    instrumentation_point
    mov ecx, symbol_value(rom_string_string_Gsymbol)
    call aux_string_to_symbol
    jmp [ebp + cont.program]

app_string_Gkeyword:
  .A1:
    instrumentation_point
    mov ecx, symbol_value(rom_string_string_Gkeyword)
    call aux_string_to_symbol
    mov al, keyword_tag
    jmp [ebp + cont.program]

;;
;; aux_string_to_symbol (native procedure)
;;
;; preconditions:  EBX = value
;;                 ECX = symbol for error reporting
;;
;; postconditions: EAX = symbol
;;
aux_string_to_symbol:
    cmp bl, string_tag
    jne .error
    mov esi, ground_private_lookup_table + 4*(rom_string_intern - 1)
    mov edx, [esi]
    cmp dl, nil_tag
    jz .load_rom
  .work:
    mov edi, fixint_value(0)
    call cb_insert
    jnz .new_symbol
    ret
  .error:
    mov eax, err_invalid_argument
    jmp rn_error
  .new_symbol:
    call rn_get_blob_data
    call rn_allocate_blob
    mov al, symbol_tag
    mov [esi + edi - 1], eax
    xchg eax, ebx
    call rn_copy_blob_data
    xchg eax, ebx
    ret
  .load_rom:
    rn_trace configured_debug_gc_blobs, 'load-rom-symbols'
    push ebx
    mov ebx, symbol_tag
  .next_descriptor:
    add ebx, 0x100
    mov esi, ground_private_lookup_table + 4*(rom_string_intern - 1)
    mov edi, fixint_value(0)
    call cb_insert
    mov [esi + edi - 1], ebx
    cmp ebx, ((blob_descriptors.ram - blob_descriptors) / 8 - 1) << 8
    jb .next_descriptor
    mov esi, ground_private_lookup_table + 4*(rom_string_intern - 1)
    pop ebx
    jmp .work

app_symbol_Gstring:
  .A1:
    instrumentation_point
    cmp bl, symbol_tag
    mov ecx, symbol_value(rom_string_symbol_Gstring)
    jne .error
    mov bl, string_tag
    mov eax, ebx
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    jmp rn_error

app_symbol_Gkeyword:
  .A1:
    instrumentation_point
    cmp bl, symbol_tag
    mov ecx, symbol_value(rom_string_symbol_Gkeyword)
    jne app_symbol_Gstring.error
    mov bl, keyword_tag
    mov eax, ebx
    jmp [ebp + cont.program]

app_keyword_Gstring:
  .A1:
    instrumentation_point
    cmp bl, keyword_tag
    mov ecx, symbol_value(rom_string_keyword_Gstring)
    jne app_symbol_Gstring.error
    mov bl, string_tag
    mov eax, ebx
    jmp [ebp + cont.program]

app_keyword_Gsymbol:
  .A1:
    instrumentation_point
    cmp bl, keyword_tag
    mov ecx, symbol_value(rom_string_keyword_Gsymbol)
    jne app_symbol_Gstring.error
    mov bl, symbol_tag
    mov eax, ebx
    jmp [ebp + cont.program]
