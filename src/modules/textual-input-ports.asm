;;;
;;; textual-input-ports.asm
;;;
;;; String and utf-8 input ports.
;;;

app_open_input_string:
  .A1:
    ;; ebx = input string/symbol/keyword/bytevector
    ;; ebp = continuation
    mov eax, ebx
    xor al, (symbol_tag & bytevector_tag)
    test al, ~(symbol_tag ^ bytevector_tag)
    jnz .open_error
    mov ecx, 12
    call rn_allocate
    mov [eax + txt_in.header], dword txt_in_header(12)
    mov [eax + txt_in.env], eax
    mov [eax + txt_in.close], dword primitive_value(primop_no_op)
    mov [eax + txt_in.read], dword primitive_value(.read_method)
    mov [eax + txt_in.peek], dword primitive_value(.peek_method)
    mov [eax + txt_in.buffer], ebx
    mov [eax + txt_in.bufpos], dword fixint_value(0)
    mov [eax + txt_in.state], dword fixint_value(0)
    mov [eax + txt_in.accum], dword fixint_value(0)
    mov [eax + txt_in.underlying_port], dword inert_tag
    mov [eax + txt_in.line], dword fixint_value(1)
    mov [eax + txt_in.column], dword fixint_value(1)
    jmp [ebp + cont.program]
  .open_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_input_string)
    jmp rn_error

    align 4
  .read_method:
    push dword .read_success
    jmp .read_peek_common

    align 4
  .peek_method:
    push dword .peek_success
    jmp .read_peek_common

  .read_peek_common:
    ;; edi = port object
    ;; ebx = argument (unused)
    ;; ebp = continuation
    ;; native stack(0) = success handler
    mov ecx, [edi + txt_in.accum]
    cmp cl, char_tag
    jz .ret_ret
    mov esi, edi
    call txt_in_try_buffer
    cmp ebx, fixint_value(UTF8_ACCEPT)
    jne .error_at_end
    mov eax, dword eof_tag
    jmp [ebp + cont.program]
  .ret_ret:
    ret
  .error_at_end:
    mov eax, err_invalid_utf8
    mov ebx, edi
    pop edx
    jmp rn_error
  .read_success:
    call txt_in_update_position
    mov [edi + txt_in.accum], dword fixint_value(0)
  .peek_success:
    mov eax, ecx
    jmp [ebp + cont.program]

app_open_utf_decoder:
  .A1:
    ;; ebx = port
    ;; ebp = continuation
    mov edx, ebx
    test bl, 3
    jnz .type_error
    mov eax, [edx]
    cmp al, bin_in_header(0)
    jne .type_error
    mov ecx, 12
    call rn_allocate
    mov [eax + txt_in.header], dword txt_in_header(12)
    mov [eax + txt_in.env], eax
    mov [eax + txt_in.close], dword primitive_value(.close_method)
    mov [eax + txt_in.read], dword primitive_value(.read_method)
    mov [eax + txt_in.peek], dword primitive_value(.peek_method)
    mov [eax + txt_in.buffer], dword bytevector_value(rom_empty_string)
    mov [eax + txt_in.bufpos], dword fixint_value(0)
    mov [eax + txt_in.state], dword fixint_value(0)
    mov [eax + txt_in.accum], dword fixint_value(0)
    mov [eax + txt_in.underlying_port], edx
    mov [eax + txt_in.line], dword fixint_value(1)
    mov [eax + txt_in.column], dword fixint_value(1)
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_utf_decoder)
    jmp rn_error

    align 4
  .close_method:
    mov esi, [edi + txt_in.underlying_port]
    mov eax, [esi + bin_in.close]
    mov edi, [esi + bin_in.env]
    jmp rn_combine

    align 4
  .read_method:
    mov edx, .read_success
    jmp .read_peek_common

    align 4
  .peek_method:
    mov edx, .peek_success
    jmp .read_peek_common

  .return_accumulated:
    jmp edx
  .read_peek_common:
    ;; edi = port object
    ;; edx = success handler
    ;; ebp = continuation
    mov ecx, [edi + txt_in.accum]
    cmp cl, char_tag
    jz .return_accumulated
    cmp cl, eof_tag
    jz .end_of_file_again
    push edx
    push dword .success
    mov esi, edi
    call txt_in_try_buffer
  .refill:
    pop edx
    ;; ebx = decoder state
    ;; edx = success handler
    ;; save port object, decoder state
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], ebx
    mov [eax + cont.var1], edx
    mov [eax + cont.var2], edi
    mov ebp, eax
    ;; discard the current buffer
    mov [edi + txt_in.bufpos], dword fixint_value(0)
    mov [edi + txt_in.buffer], dword bytevector_value(rom_empty_string)
    ;; call underlying read method
    mov edi, [edi + txt_in.underlying_port]
    mov eax, [edi + bin_in.read]
    mov ebx, fixint_value(configured_default_buffer_size)
    mov edi, [edi + bin_in.env]
    jmp rn_combine
  .continue:
    ;; restore port object, success address and decoder state
    mov ebx, [ebp + cont.var0]
    mov edx, [ebp + cont.var1]
    mov edi, [ebp + cont.var2]
    mov ebp, [ebp + cont.parent]
    ;; analyze binary data read from the underlying port
    cmp al, eof_tag
    je .end_of_file
    cmp al, bytevector_tag
    jne .bad_data
    ;; restart reading from the new string
    mov [edi + txt_in.buffer], eax
    jmp .read_peek_common
  .end_of_file:
    cmp ebx, fixint_value(UTF8_ACCEPT)
    jne .error_at_end
    mov [edi + txt_in.accum], eax
    mov ecx, eof_tag
    jmp edx
  .bad_data:
    mov ebx, eax
    mov eax, err_port_incompatibility
    jmp rn_error
  .end_of_file_again:
    mov eax, eof_tag
    jmp edx
  .error_at_end:
    mov eax, err_invalid_utf8
    mov ebx, edi
    jmp rn_error
  .success:
    pop edx
    jmp edx
  .read_success:
    call txt_in_update_position
    mov [edi + txt_in.accum], dword fixint_value(0)
  .peek_success:
    mov eax, ecx
    jmp [ebp + cont.program]

;;
;; txt_in_update_position (native procedure)
;;
;; Update line and column indices based on character read.
;;
;; preconditions:  ECX = character (tagged) or eof-object
;;                 EDI = textual input port object
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX
;;
;; TODO: switch to bigint on overflow.
;;
txt_in_update_position:
    ;; ecx = char
    cmp cl, char_tag
    jne .done
    cmp ecx, char_value(10)
    je .down
  .right:
    mov eax, [edi + txt_in.column]
    lea eax, [eax + fixint_value(1) - fixint_value(0)]
    mov [edi + txt_in.column], eax
    ret
  .down:
    mov eax, [edi + txt_in.line]
    lea eax, [eax + fixint_value(1) - fixint_value(0)]
    mov [edi + txt_in.line], eax
    mov [edi + txt_in.column], dword fixint_value(1)
  .done:
    ret

app_get_textual_input_position:
  .A0:
    mov ebx, private_binding(rom_string_stdin)
  .A1:
    test bl, 3
    jnz .type_error
    mov eax, [ebx + txt_in.header]
    cmp al, txt_in_header(0)
    jne .type_error
    push dword [ebx + txt_in.column]
    push dword nil_tag
    call rn_cons
    push dword [ebx + txt_in.line]
    push eax
    call rn_cons
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_textual_input_position)
    jmp rn_error

    
txt_in_try_buffer:
    ;; pre:   esi = textual input port object with buffer
    ;;        native stack (0) = fail return address
    ;;        native stack (1) = success return address
    ;; post. if character can be read from the buffer:
    ;;  eip = success return address
    ;;  ecx = character (tagged)
    ;;  esi = port object (accumulator is char)
    ;; post. if there is not enough bytes:
    ;;  eip = fail return address
    ;;  ebx = decoder state (tagged)
    ;;  esi = port object (UTF-8 decoder state updated, accumulator is fixint)
    ;; post. if the buffer contains invalid UTF-8 sequence
    ;;  eax = error message
    ;;  esi = port object
    ;;  eip = rn_error
    push esi
    push edi
    mov ebx, [esi + txt_in.buffer]
    call rn_get_blob_data
    push ebx                          ; save buffer start
    add ecx, ebx                      ; compute end pointer
    mov edi, ecx
    mov edx, [esi + txt_in.bufpos]    ; get position
    shr edx, 2                        ;  untag
    add edx, ebx                      ;  get pointer
    mov ebx, [esi + txt_in.state]     ; get decoder state
    shr ebx, 2                        ;  untag
    mov ecx, [esi + txt_in.accum]     ; get decoder accumulator
    shr ecx, 2                        ;  untag
    mov esi, edx
  .decode_loop:
    ;; ebx = UTF-8 decoder state
    ;; ecx = UTF-8 decoder codepoint accumulator
    ;; esi = pointer to next input byte
    ;; edi = pointer past input end
    cmp esi, edi
    jae .overrun
    movzx eax, byte [esi]
    inc esi
    call rn_decode_utf8
    cmp bl, UTF8_REJECT
    je .invalid
    test bl, bl
    jnz .decode_loop
    pop eax        ; get buffer start
    sub esi, eax   ; compute new offset
    mov eax, esi
    lea eax, [4 * eax + fixint_tag] ; tag position as fixint
    lea ebx, [4 * ebx + fixint_tag] ;     decoder state
    shl ecx, 8                      ; tag codepoint
    or cl, char_tag                 ;     as char
    pop edi                         ; restore heap pointer
    pop esi                         ; restore port object
    mov [esi + txt_in.bufpos], eax  ; save position
    mov [esi + txt_in.state], ebx   ;      decoder state
    mov [esi + txt_in.accum], ecx   ;      accumulator
    add esp, 4                      ; discard fail address
    ret                             ; jump to success address
  .overrun:
    pop edx
    pop edi
    pop esi
    lea ebx, [4 * ebx + fixint_tag] ; tag decoder state as fixint
    lea ecx, [4 * ecx + fixint_tag] ;     accumulator
    mov [esi + txt_in.state], ebx   ; save decoder state
    mov [esi + txt_in.accum], ecx   ;      accumulator
    pop edx
    pop eax
    jmp edx
  .invalid:
    add esp, 20
    mov ebx, esi
    mov eax, err_invalid_utf8
    jmp rn_error
