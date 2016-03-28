;;;
;;; binary-output-ports.asm
;;;
;;; Bytevector ports.
;;;

app_open_output_bytevector:
  .A0:
    instrumentation_point
    mov ebx, fixint_value(configured_default_buffer_size)
    ; fallthrough
  .A1:
    instrumentation_point
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
    mov [eax + bin_out.header], dword bin_out_header(8)
    mov [eax + bin_out.env], eax
    mov [eax + bin_out.close], dword primitive_value(primop_no_op)
    mov [eax + bin_out.write], dword primitive_value(.write_method)
    mov [eax + bin_out.flush], dword primitive_value(primop_no_op)
    mov [eax + bin_out.buffer], ebx
    mov [eax + bin_out.usage], dword fixint_value(0)
    mov [eax + bin_out.underlying_port], dword inert_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_buffer_size
    mov ecx, symbol_value(rom_string_open_output_bytevector)
    jmp rn_error

    align 4
  .write_method:
    ;; ebx = argument
    ;; edi = port object
    ;; ebp = continuation
    mov esi, ebx                    ; ESI := object to be written
  .write_restart:
    push dword .success
    call bin_out_try_buffer         ; EDX := capacity needed
    mov ecx, edx                    ; ECX := capacity needed
    shr edx, 1                      ; EDX := capacity needed / 2
    add ecx, edx                    ; ECX := capacity needed * 3/2
    call rn_allocate_blob
    mov ebx, eax                    ; EBX := new buffer
    mov eax, [edi + txt_out.buffer] ; EAX := old buffer
    mov ecx, [edi + txt_out.usage]  ; ECX := old buffer usage
    shr ecx, 2                      ;        untagged
    call rn_copy_blob_data
    mov [edi + txt_out.buffer], ebx ; save new buffer in port obj.
    mov ebx, esi                    ; EBX := object to be written
    jmp .write_restart
  .success:
    mov eax, dword inert_tag
    jmp [ebp + cont.program]

app_get_output_bytevector:
  .A1:
    instrumentation_point
    ;; eax = closure (not used)
    ;; ebx = port object
    ;; edi = environment (not used)
    ;; ebp = continuation
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, bin_out_header(0)
    jne .type_error
    cmp [ebx + bin_out.write], dword primitive_value(app_open_output_bytevector.write_method)
    jne .type_error
    mov edi, ebx
    mov ecx, [edi + bin_out.usage]
    shr ecx, 2
    call rn_allocate_blob
    mov ebx, eax
    mov eax, [edi + bin_out.buffer]
    mov ecx, [edi + bin_out.usage]
    shr ecx, 2
    call rn_copy_blob_data
    mov eax, ebx
    xor edi, edi
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_output_bytevector)
    jmp rn_error

app_get_output_bytevector_position:
  .A1:
    instrumentation_point
    ;; eax = closure (not used)
    ;; ebx = port object
    ;; edi = environment (not used)
    ;; ebp = continuation
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, bin_out_header(0)
    jne .type_error
    cmp [ebx + bin_out.write], dword primitive_value(app_open_output_bytevector.write_method)
    jne .type_error
    mov eax, [ebx + bin_out.usage]
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_get_output_bytevector_position)
    jmp rn_error

;;
;; app_open_buffered_binary_output_port (continuation passing procedure)
;;

app_open_buffered_binary_output_port:
  .A1:
    instrumentation_point
    mov ecx, fixint_value(configured_default_buffer_size)
    ; fallthrough
  .A2:
    instrumentation_point
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
    mov [eax + bin_out.header], dword bin_out_header(8)
    mov [eax + bin_out.env], eax
    mov [eax + bin_out.close], dword primitive_value(.close_method)
    mov [eax + bin_out.write], dword primitive_value(.write_method)
    mov [eax + bin_out.flush], dword primitive_value(.flush_method)
    mov [eax + bin_out.buffer], ebx
    mov [eax + bin_out.usage], dword fixint_value(0)
    mov [eax + bin_out.underlying_port], edx
    jmp [ebp + cont.program]
  .port_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_buffered_binary_output_port)
    jmp rn_error
  .buffer_error:
    mov eax, err_invalid_buffer_size
    mov ebx, ecx
    mov ecx, symbol_value(rom_string_open_buffered_binary_output_port)
    jmp rn_error

    align 4
  .write_method:
    ;; ebx = argument
    ;; edi = closure
    ;; ebp = continuation
  .write_restart:
    push ebx
    push dword .success
    call bin_out_try_buffer
    ;; ecx = current buffer usage (untagged)
    ;; edx = capacity needed (untagged)
    ;; [esp] = argument (string or char)
    test ecx, ecx
    jz .big
    pop ebx
    mov edx, .write_continue
    call make_helper_continuation
    call rn_allocate_blob ; eax = temporary buffer
    mov ebx, eax
    mov eax, [edi + bin_out.buffer]
    call rn_copy_blob_data
    mov [edi + bin_out.usage], dword fixint_value(0)
    mov edi, [edi + bin_out.underlying_port]
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
    mov edi, [edi + bin_out.underlying_port]
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
    mov ecx, [edi + bin_out.usage]
    shr ecx, 2
    jz .no_op
    mov edx, .flush_continue
    call make_helper_continuation
    call rn_allocate_blob
    mov ebx, eax
    mov eax, [edi + bin_out.buffer]
    call rn_copy_blob_data
    mov [edi + bin_out.usage], dword fixint_value(0)
    mov edi, [edi + bin_out.underlying_port]
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
    mov edi, [edi + bin_out.underlying_port]
    mov eax, [edi + bin_out.close]
    mov edi, [edi + bin_out.env]
    jmp rn_combine

;;
;; bin_out_try_buffer (native procedure)
;;
;; preconditions:  EBX = fixint, bytevector or string
;;                 EDI = binary output port object with buffer
;;                 [ESP] = fail return address
;;                 [ESP + 4] = success return address
;;
;; postconditions if buffer suffices:
;;                 EIP = success return address
;;                 EDI = port object (data added to the buffer)
;;
;; postconditions if buffer overflows:
;;                 EIP = fail return address
;;                 ECX = current buffer usage (untagged)
;;                 EDX = capacity needed (untagged)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;;

bin_out_try_buffer:
    cmp bl, bytevector_tag
    jz .write_bytevector
    cmp bl, string_tag
    jz .write_bytevector
    cmp bl, char_tag
    jz .write_char
  .write_byte:
    mov eax, ebx
    shr eax, 2                       ; EAX = byte (untagged)
    mov edx, [edi + bin_out.usage]
    shr edx, 2                       ; EDX = usage (unagged)
    mov ebx, [edi + bin_out.buffer]
    call rn_get_blob_data
    cmp ecx, edx
    jbe .byte_overflow
    mov [ebx + edx], al              ; store byte
    lea edx, [4 * (edx + 1) + 1]     ; EDX := tagged new usage
    mov [edi + bin_out.usage], edx   ; store new usage
    pop eax                          ; discard fail return address
    ret
  .byte_overflow:
    inc edx             ; EDX := capacity needed
    mov eax, [esp]      ; EAX := fail return address
    add esp, 8          ; remove return addresses from the stack
    jmp eax
  .write_bytevector:
    call rn_get_blob_data            ; EBX := argument address, ECX := argument length
  .write_data:
    push ebx
    push ecx
    mov edx, [edi + bin_out.usage]
    shr edx, 2                       ; EDX := old usage (untagged)
    mov eax, edx                     ; EAX := old usage (untagged)
    add edx, ecx                     ; EDX := capacity needed
    mov ebx, [edi + bin_out.buffer]  ; EBX := buffer object
    call rn_get_blob_data            ; EBX := buffer address, ECX := buffer capacity
    cmp ecx, edx
    jb .bytevector_overflow
    add ebx, eax                     ; EBX := offset in buffer
    pop ecx                          ; ECX := argument length
    pop eax                          ; EAX := argument data address
    call rn_copy_blob_data
    lea eax, [4*edx + 1]
    mov [edi + bin_out.usage], eax
    pop eax
    ret
  .bytevector_overflow:
    mov ecx, eax        ; ECX := current usage
    mov eax, [esp + 8]  ; fail return address
    add esp, 16         ; remove local variables and return addressed from the stack
    jmp eax
  .write_char:
    mov eax, ebx
    mov ebx, scratchpad_start
    call rn_encode_utf8
    jmp .write_data
