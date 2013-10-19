;;;
;;; textual-output-ports.asm
;;;
;;; String and utf8 output ports.
;;;

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
    mov [eax + txt_out.close], dword primitive_value(.close_method)
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

  .close_method:
    mov edx, .close_continue
    call make_helper_continuation
    jmp .flush_method
  .close_continue:
    call discard_helper_continuation
    call rn_disable_port_methods ;; TODO: leak?
    mov edi, [edi + txt_out.underlying_port]
    mov eax, [edi + bin_out.close]
    mov edi, [edi + bin_out.env]
    jmp rn_combine

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
