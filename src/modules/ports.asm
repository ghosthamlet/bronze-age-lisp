;;;
;;; ports.asm
;;;
;;; Kernel port features.
;;;

%if configured_stdio

;;
;; check_port_type (native procedure)
;;
;; preconditions:  EBX = port object
;;                 ESI = unwrapped port applicative closure
;;                   .var2 = applicative name
;;                   .var3 = expected header (tagged integer)
;;                   .var4 = (not used here)
;;
;; postconditions: return if port matches the expected tag
;;                 jump to rn_error otherwise
;;
;; preserves:      EBX, ECX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;;
check_port_type:
    mov edx, [esi + operative.var3]
    shr edx, 2
    test bl, 3
    jnz .invalid_port
    mov eax, [ebx]
    cmp al, dl
    jne .invalid_port
    ret
  .invalid_port:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var2]
    jmp rn_error

app_read_typed:
  .A0:
    ;; eax = closure (var2 = name, var3 = port tag, var4 = method index)
    ;; edi = dynamic environment (not used)
    ;; ebp = continuation
    mov ebx, private_binding(rom_string_stdin)
    ; fallthrough
  .A1:
    ;; eax = closure (var0 = name, var1 = port tag, var2 = method index)
    ;; ebx = port object
    ;; edi = dynamic environment (not used)
    ;; ebp = continuation
    call check_port_type
    mov edx, [esi + operative.var4]    ; method index (tagged fixint)
    mov eax, [ebx + edx - 1]           ; method combiner
    mov edi, [ebx + bin_out.env]       ; environment for port method
    mov ebx, inert_tag                 ; method argument
    rn_trace configured_debug_ports, 'read-typed', hex, esi, hex, edx
    jmp rn_combine

app_write_typed:
  .A1:
    ;; ebx = argument (char / string / bytevector)
    ;; esi = closure (var2 = name, var3 = port tag, var4 = object tag)
    ;; edi = dynamic environment (not used)
    ;; ebp = continuation
    mov ecx, private_binding(rom_string_stdout)
    ; fallthrough
  .A2:
    ;; ebx = argument
    ;; ecx = port object
    ;; esi = closure (var0 = name, var1 = port tag, var2 = object tag)
    ;; edi = dynamic environment (not used)
    ;; ebp = continuation
    xchg ebx, ecx
    call check_port_type
    mov edx, [esi + operative.var4]
    shr edx, 2
    cmp cl, dl
    jne .invalid_argument
    mov eax, [ebx + bin_out.write]      ; method combiner
    mov edi, [ebx + bin_out.env]        ; env. for port method
    xchg ebx, ecx                       ; method argument
    jmp rn_combine
  .invalid_argument:
    mov eax, err_invalid_argument       ; error message
    mov ebx, ecx                        ; irritant argument
    mov ecx, [esi + operative.var2]     ; applicative's name
    jmp rn_error

app_flush_output_port:
  .A0:
    ;; ebx = argument (output port object)
    ;; esi = closure (not used)
    ;; edi = dynamic environment (not used)
    ;; ebp = continuation
    mov ebx, private_binding(rom_string_stdout)
  .A1:
    mov edx, eax
    test bl, 3
    jnz .invalid_port
    mov eax, [ebx]
    xor al, (txt_out_header(0) & bin_out_header(0))
    test al, ~(txt_out_header(0) ^ bin_out_header(0))
    jnz .invalid_port
    mov eax, [ebx + txt_out.flush] ; method combiner
    mov edi, [ebx + bin_out.env]   ; environment for port method
    mov ebx, inert_tag             ; method argument
    jmp rn_combine
  .invalid_port:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_flush_output_port)
    jmp rn_error

app_close_typed:
  .A1:
    ;; EBX = port object
    ;; ESI = unwrapped applicative closure
    ;;  .var1 = applicative name
    ;;  .var2 = header test value (tagged integer)
    ;;  .var3 = header mask (not used here)
    ;; EBP = continuation
    test bl, 3
    jnz .invalid_port
    mov ecx, [ebx]
    mov edx, [esi + operative.var2]
    shr edx, 2
    xor ecx, edx
    mov edx, [esi + operative.var3]
    shr edx, 2
    test ecx, edx
    jnz .invalid_port
    mov eax, [ebx + txt_out.close] ; method combiner
    mov edi, [ebx + bin_out.env]   ; environment for port method
    mov ebx, inert_tag             ; method argument
    jmp rn_combine
  .invalid_port:
    mov ecx, [eax + operative.var1]
    mov eax, err_invalid_argument
    push app_close_typed
    jmp rn_error

%define txt_out.buffer          txt_out.var0
%define txt_out.usage           txt_out.var1
%define txt_out.underlying_port txt_out.var2

app_open_output_string:
  .A0:
    mov ebx, fixint_value(configured_default_buffer_size)
    ; fallthrough
  .A1:
    ;; eax = closure (not used)
    ;; ebx = buffer size (tagged fixint)
    ;; edi = environment (not used)
    ;; ebp = continuation
    mov eax, ebx
    xor al, 1
    test al, 3
    jnz .error
    cmp ebx, fixint_value(configured_blob_heap_size / 2)
    ja .error
    mov ecx, ebx
    shr ecx, 2
    call rn_allocate_blob
    mov ebx, eax
    mov ecx, 8
    call rn_allocate
    mov [eax + txt_out.header], dword txt_out_header(8)
    mov [eax + txt_out.env], eax
    mov [eax + txt_out.close], dword primitive_value(primop_no_op)
    mov [eax + txt_out.write], dword primitive_value(.write_method)
    mov [eax + txt_out.flush], dword primitive_value(primop_no_op)
    mov [eax + txt_out.buffer], ebx
    mov [eax + txt_out.usage], dword fixint_value(0)
    mov [eax + txt_out.underlying_port], dword inert_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_buffer_size
    mov ecx, symbol_value(rom_string_open_output_string)
    jmp rn_error

    align 4
  .write_method:
    ;; ebx = argument
    ;; edi = port object
    ;; ebp = continuation
    push ebx
  .write_restart:
    push dword .success
    mov esi, edi
    call txt_out_try_buffer  ; edx = capacity needed
    mov ecx, edx
    shr edx, 1
    add ecx, edx
    call rn_allocate_blob  ; eax = new buffer
    mov ebx, eax
    mov eax, [edi + txt_out.buffer]
    mov ecx, [edi + txt_out.usage]
    shr ecx, 2
    call rn_copy_blob_data
    mov [edi + txt_out.buffer], ebx
    mov ebx, [esp]
    jmp .write_restart
  .success:
    pop eax
    mov eax, dword inert_tag
    jmp [ebp + cont.program]

app_get_output_string:
  .A1:
    ;; eax = closure (not used)
    ;; ebx = port object
    ;; edi = environment (not used)
    ;; ebp = continuation
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, txt_out_header(0)
    jne .type_error
    cmp [ebx + txt_out.write], dword primitive_value(app_open_output_string.write_method)
    jne .type_error
    mov edi, ebx
    mov ecx, [edi + txt_out.usage]
    shr ecx, 2
    call rn_allocate_blob
    mov ebx, eax
    mov eax, [edi + txt_out.buffer]
    mov ecx, [edi + txt_out.usage]
    shr ecx, 2
    call rn_copy_blob_data
    mov eax, ebx
    mov al, string_tag
    xor edi, edi
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_output_string)
    jmp rn_error

app_open_utf_encoder:
  .A1:
    mov ecx, fixint_value(configured_default_buffer_size)
    ; fallthrough
  .A2:
    ;; eax = closure (not used)
    ;; ebx = underlying port
    ;; ecx = buffer size (tagged fixint)
    ;; edi = environment (not used)
    ;; ebp = continuation
    mov edx, ebx
    test bl, 3
    jnz .port_error
    mov eax, [ebx]
    cmp al, bin_out_header(0)
    jne .port_error

    mov eax, ecx
    xor al, 1
    test al, 3
    jnz .buffer_error
    cmp ecx, fixint_value(configured_blob_heap_size / 2)
    ja .buffer_error
    shr ecx, 2

    call rn_allocate_blob
    mov ebx, eax
    mov ecx, 8
    call rn_allocate
    mov [eax + txt_out.header], dword txt_out_header(8)
    mov [eax + txt_out.env], eax
    mov [eax + txt_out.close], dword primitive_value(.flush_method)
    mov [eax + txt_out.write], dword primitive_value(.write_method)
    mov [eax + txt_out.flush], dword primitive_value(.flush_method)
    mov [eax + txt_out.buffer], ebx
    mov [eax + txt_out.usage], dword fixint_value(0)
    mov [eax + txt_out.underlying_port], edx
    jmp [ebp + cont.program]
  .port_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_utf_encoder)
    jmp rn_error
  .buffer_error:
    mov eax, err_invalid_buffer_size
    mov ebx, ecx
    mov ecx, symbol_value(rom_string_open_utf_encoder)
    jmp rn_error

    align 4
  .write_method:
    ;; ebx = argument
    ;; edi = closure
    ;; ebp = continuation
  .write_restart:
    push ebx
    push dword .success
    mov esi, edi
    call txt_out_try_buffer
    ;;  ebx = current buffer usage (untagged)
    ;;  ecx = size of the object in bytes (untagged)
    ;;  edx = capacity needed (untagged)
    ;; [esp] = argument (string or char)
    mov ecx, ebx
    test ebx, ebx
    jz .big
    pop ebx
    mov edx, .write_continue
    call make_helper_continuation
    call rn_allocate_blob ; eax = temporary string
    mov ebx, eax
    mov eax, [edi + txt_out.buffer]
    call rn_copy_blob_data
    mov [edi + txt_out.usage], dword fixint_value(0)
    mov edi, [edi + txt_out.underlying_port]
    mov eax, [edi + bin_out.write]
    mov edi, [edi + bin_out.env]
    jmp rn_combine
  .write_continue:
    ;; TODO handle partial write
    rn_trace configured_debug_ports, 'W', hex, eax
    call discard_helper_continuation
    jmp .write_restart
  .big:
    ;; buffer empty, but the item still does not fit
    ;; pass it directly to the output port
    pop ebx
    mov edi, [edi + txt_out.underlying_port]
    mov eax, [edi + bin_out.write]
    mov edi, [edi + bin_out.env]
    jmp rn_combine
  .success:
    pop eax
    mov eax, dword inert_tag
    jmp [ebp + cont.program]

    align 4
  .flush_method:
    ;; ebx = argument (ignored)
    ;; edi = port object
    ;; ebp = continuation
    mov ecx, [edi + txt_out.usage]
    shr ecx, 2
    jz .no_op
    mov edx, .flush_continue
    call make_helper_continuation
    call rn_allocate_blob
    mov ebx, eax
    mov eax, [edi + txt_out.buffer]
    call rn_copy_blob_data
    mov [edi + txt_out.usage], dword fixint_value(0)
    mov edi, [edi + txt_out.underlying_port]
    mov eax, [edi + bin_out.write]
    mov edi, [edi + bin_out.env]
    jmp rn_combine
  .flush_continue:
    ;; TODO check result & partial writes
    call discard_helper_continuation
  .no_op:
    mov eax, dword inert_tag
    jmp [ebp + cont.program]

txt_out_try_buffer:
    ;; pre:   esi = textual output port object with buffer
    ;;        ebx = char or string object
    ;;        native stack (0) = fail return address
    ;;        native stack (1) = success return address
    ;; if buffer suffices:
    ;;  eip = success return address
    ;;  esi = port object (data added to the buffer)
    ;; post if buffer overflows:
    ;;  eip = fail return address
    ;;  ebx = current buffer usage (untagged)
    ;;  ecx = size of the object in bytes (untagged)
    ;;  edx = capacity needed (untagged)
    ;;
    cmp bl, char_tag
    jz .write_char
  .write_string:
    ;; TODO check???
    call rn_get_blob_data
  .write_data:
    ;; ebx = byte array (temporary pointer)
    ;; ecx = byte count (untagged)
    push esi
    mov edx, [esi + txt_out.usage]
    shr edx, 2
    push edx
    push ebx
    push ecx
    add edx, ecx
    mov ebx, [esi + txt_out.buffer]
    mov eax, ebx
    call rn_get_blob_data
    cmp edx, ecx
    ja .overflow
    ;; eax = buffer string value
    ;; ebx = buffer base
    ;; ecx = capacity
    ;; edx = usage + item length
    ;; esi = port object
    ;; native stack(0) = item length
    ;; native stack(1) = item data (untagged)
    ;; native stack(2) = current buffer usage (untagged)
    ;; native stack(3) = port object
    ;; native stack(4) = fail return address
    ;; native stack(5) = success return address
    pop ecx
    pop esi
    pop edx
    push edi
    mov edi, ebx
    add edi, edx
    rep movsb
    sub edi, ebx
    mov edx, edi
    shl edx, 2
    pop edi
    pop esi
    or dl, fixint_tag
    pop eax
    mov [esi + txt_out.usage], edx
    ret
  .overflow:
    pop ecx
    add esp, 4
    pop ebx
    pop esi
    pop eax
    add esp, 4
    jmp eax
  .write_char:
    mov eax, ebx
    mov ebx, scratchpad_start
    push dword .write_data
    jmp rn_encode_utf8

%define txt_in.buffer          txt_out.var0
%define txt_in.bufpos          txt_out.var1
%define txt_in.state           txt_out.var2
%define txt_in.accum           txt_out.var3
%define txt_in.underlying_port txt_out.var4

app_open_input_string:
  .A1:
    ;; ebx = input string/symbol/keyword/bytevector
    ;; ebp = continuation
    mov eax, ebx
    xor al, (symbol_tag & bytevector_tag)
    test al, ~(symbol_tag ^ bytevector_tag)
    jnz .open_error
    mov ecx, 10
    call rn_allocate
    mov [eax + txt_in.header], dword txt_in_header(10)
    mov [eax + txt_in.env], eax
    mov [eax + txt_in.close], dword primitive_value(primop_no_op)
    mov [eax + txt_in.read], dword primitive_value(.read_method)
    mov [eax + txt_in.peek], dword primitive_value(.peek_method)
    mov [eax + txt_in.buffer], ebx
    mov [eax + txt_in.bufpos], dword fixint_value(0)
    mov [eax + txt_in.state], dword fixint_value(0)
    mov [eax + txt_in.accum], dword fixint_value(0)
    mov [eax + txt_in.underlying_port], dword inert_tag
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
    mov ecx, 10
    call rn_allocate
    mov [eax + txt_in.header], dword txt_in_header(10)
    mov [eax + txt_in.env], eax
    mov [eax + txt_in.close], dword primitive_value(.close_method)
    mov [eax + txt_in.read], dword primitive_value(.read_method)
    mov [eax + txt_in.peek], dword primitive_value(.peek_method)
    mov [eax + txt_in.buffer], dword bytevector_value(rom_empty_string)
    mov [eax + txt_in.bufpos], dword fixint_value(0)
    mov [eax + txt_in.state], dword fixint_value(0)
    mov [eax + txt_in.accum], dword fixint_value(0)
    mov [eax + txt_in.underlying_port], edx
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
    mov [edi + txt_in.accum], dword fixint_value(0)
  .peek_success:
    mov eax, ecx
    jmp [ebp + cont.program]

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

app_open_binary_input_file:
  .A1:
    ;; ebx = name
    cmp bl, string_tag
    jne .error
    call linux_open_input
    mov edx, eax
    mov ecx, 6
    call rn_allocate
    mov [eax + bin_in.header], dword bin_in_header(6)
    mov [eax + bin_in.env], edx
    mov [eax + bin_in.close], dword primitive_value(linux_close)
    mov [eax + bin_in.read], dword primitive_value(linux_read)
    mov [eax + bin_in.peek], dword primitive_value(linux_nop)
    mov [eax + bin_in.var0], edx ; dummy
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_binary_input_file)
    jmp rn_error

app_open_binary_output_file:
  .A1:
    ;; ebx = name
    cmp bl, string_tag
    jne .error
    call linux_open_output
    mov edx, eax
    mov ecx, 6
    call rn_allocate
    mov [eax + bin_out.header], dword bin_out_header(6)
    mov [eax + bin_out.env], edx
    mov [eax + bin_out.close], dword primitive_value(linux_close)
    mov [eax + bin_out.write], dword primitive_value(linux_write)
    mov [eax + bin_out.flush], dword primitive_value(linux_nop)
    mov [eax + bin_out.var0], edx ; dummy
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_binary_input_file)
    jmp rn_error

%endif
