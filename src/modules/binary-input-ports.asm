;;;
;;; binary-input-ports.asm
;;;
;;; Bytevector and buffered input ports.
;;;

;;
;; app_open_input_bytevector (continuation passing procedure)
;;
;; preconditions:  EBX = input string/symbol/keyword/bytevector
;;                 EBP = current continuation
;;
app_open_input_bytevector:
  .A1:
    mov eax, ebx
    xor al, (symbol_tag & bytevector_tag)
    test al, ~(symbol_tag ^ bytevector_tag)
    jnz .open_error
    mov ecx, 8
    call rn_allocate
    mov [eax + bin_in.header], dword bin_in_header(8)
    mov [eax + bin_in.env], eax
    mov [eax + bin_in.close], dword primitive_value(primop_no_op)
    mov [eax + bin_in.read], dword primitive_value(.read_method)
    mov [eax + bin_in.peek], dword primitive_value(.peek_method)
    mov [eax + bin_in.buffer], ebx
    mov [eax + bin_in.bufpos], dword fixint_value(0)
    mov [eax + bin_in.underlying_port], dword inert_tag
    jmp [ebp + cont.program]
  .open_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_input_bytevector)
    jmp rn_error

  .read_method:
    push dword [ebp + cont.program]
    call bin_in_try_buffer.read_u8
    mov eax, dword eof_tag
    jmp [ebp + cont.program]
  .peek_method:
    push dword [ebp + cont.program]
    call bin_in_try_buffer.peek_u8
    mov eax, dword eof_tag
    jmp [ebp + cont.program]

app_open_buffered_binary_input_port:
  .A1:
    ;; ebx = port
    ;; ebp = continuation
    mov edx, ebx
    test bl, 3
    jnz .type_error
    mov eax, [edx]
    cmp al, bin_in_header(0)
    jne .type_error
    mov ecx, 8
    call rn_allocate
    mov [eax + bin_in.header], dword bin_in_header(8)
    mov [eax + bin_in.env], eax
    mov [eax + bin_in.close], dword primitive_value(.close_method)
    mov [eax + bin_in.read], dword primitive_value(.read_method)
    mov [eax + bin_in.peek], dword primitive_value(.peek_method)
    mov [eax + bin_in.buffer], dword bytevector_value(rom_empty_string)
    mov [eax + bin_in.bufpos], dword fixint_value(0)
    mov [eax + bin_in.underlying_port], edx
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_buffered_binary_input_port)
    jmp rn_error

  .close_method:
    mov esi, [edi + bin_in.underlying_port]
    call rn_disable_port_methods ;; TODO: leak?
    mov eax, [esi + bin_in.close]
    mov edi, [esi + bin_in.env]
    jmp rn_combine

  .peek_method:
    push dword [ebp + cont.program]
    call bin_in_try_buffer.peek_u8
    mov edx, .peek_method
    jmp .refill
  .read_method:
    push dword [ebp + cont.program]
    call bin_in_try_buffer.read_u8
    mov edx, .read_method             ; edx = retry address
  .refill: 
    ;; save port object
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], edi
    mov [eax + cont.var1], edx
    mov [eax + cont.var2], dword inert_tag
    mov ebp, eax
    ;; discard the current buffer
    mov [edi + bin_in.bufpos], dword fixint_value(0)
    mov [edi + bin_in.buffer], dword bytevector_value(rom_empty_string)
    ;; call underlying read method
    mov edi, [edi + bin_in.underlying_port]
    mov eax, [edi + bin_in.read]
    mov ebx, fixint_value(configured_default_buffer_size)
    mov edi, [edi + bin_in.env]
    jmp rn_combine
  .continue:
    ;; restore port object and retry address
    mov edi, [ebp + cont.var0]
    mov edx, [ebp + cont.var1]
    mov ebp, [ebp + cont.parent]
    ;; analyze binary data read from the underlying port
    cmp al, eof_tag
    je .end_of_file
    cmp al, bytevector_tag
    jne .bad_data
    ;; restart reading from the new blob
    mov [edi + bin_in.buffer], eax
    jmp edx
  .end_of_file:
    mov eax, eof_tag
    jmp [ebp + cont.program]
  .bad_data:
    mov ebx, eax
    mov eax, err_port_incompatibility
    mov ecx, inert_tag
    jmp rn_error

;;
;; bin_in_try_buffer (irregular procedure)
;;
;; preconditions:  EDI     = binary input port object with buffer
;;                 [ESP]   = fail return address
;;                 [ESP+4] = success return address
;; post. if a byte was read from the buffer:
;;                 EIP = success return address
;;                 EAX = byte (tagged fixint)
;;                 buffer position updated
;; post. if the buffer is empty:
;;                 EIP = fail return address
;;
;; preserves: ESI, EDI, EBP
;; clobbers:  EAX, EBX, ECX, EDX
;;
bin_in_try_buffer:
%macro bin_in_try_buffer_common 0
    mov ebx, [edi + bin_in.buffer]
    call rn_get_blob_data           ; EBX, ECX = buffer start, size
    mov edx, [edi + bin_in.bufpos]
    shr edx, 2                      ; EDX = buffer position (untagged)
    cmp edx, ecx
    jae .overrun
    movzx eax, byte [ebx + edx]     ; EAX = next byte
    lea eax, [4*eax + 1]            ; tag as fixint
    pop ecx                         ; discard fail address
%endmacro

  .read_u8:
    bin_in_try_buffer_common
    lea edx, [4*edx + 5]           ; EDX = tagged next position
    mov [edi + bin_in.bufpos], edx ; store position
    ret
  .peek_u8:
    bin_in_try_buffer_common
    ret
  .overrun:
    pop edx
    pop eax
    jmp edx
