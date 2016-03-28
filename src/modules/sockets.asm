;;;
;;; sockets.asm
;;;
;;; Low-level interface to Linux networking system calls (asm part).
;;;

app_integer_Gsocket:
  .A1:
    instrumentation_point
    ;; ebx = file descriptor (tagged integer)
    call rn_fixintP_procz
    jnz socket_type_error
    mov eax, ebx
    shl eax, 6
    mov al, socket_tag
    jmp [ebp + cont.program]

app_socket_fd:
  .A1:
    instrumentation_point
    ;; ebx = socket (tagged)
    mov esi, symbol_value(rom_string_socket_fd)
    cmp bl, socket_tag
    jne socket_type_error
    mov eax, ebx
    shr eax, 8
    lea eax, [4*eax + 1]
    jmp [ebp + cont.program]

app_socket:
  .A3:
    instrumentation_point
    mov esi, symbol_value(rom_string_socket)
    ;; ebx = domain (fixint)
    ;; ecx = type (fixint)
    ;; edx = protocol (fixint)
    call rn_fixintP_procz
    jnz socket_type_error
    xchg ebx, ecx                   ; ebx := type, ecx := domain
    call rn_fixintP_procz
    jnz socket_type_error
    xchg ebx, edx                   ; ebx := protocol, edx := type
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2                      ; untag
    sar ecx, 2
    sar edx, 2
    mov [scratchpad_start], ecx     ; domain (untagged)
    mov [scratchpad_start + 4], edx ; type (untagged)
    mov [scratchpad_start + 8], ebx ; protocol (untagged)
    xor edx, edx
    mov ecx, scratchpad_start
    mov ebx, 1                      ; SYS_SOCKET
    call linux_socketcall
    shl eax, 8
    mov al, socket_tag
    jmp [ebp + cont.program]

socket_type_error:
    mov eax, err_invalid_argument
    mov ecx, esi
    jmp rn_error

app_bind:
  .A2:
    instrumentation_point
    mov esi, symbol_value(rom_string_bind)
    call socket_prepare_sockaddr
    mov ebx, 2                       ; SYS_BIND
    call linux_socketcall
    mov eax, inert_tag
    jmp [ebp + cont.program]

app_connect:
  .A2:
    instrumentation_point
    mov esi, symbol_value(rom_string_connect)
    call socket_prepare_sockaddr
    mov ebx, 3                       ; SYS_CONNECT
    call linux_socketcall
    mov eax, inert_tag
    jmp [ebp + cont.program]

app_listen:
  .A2:
    instrumentation_point
    ;; ebx = socket (tagged)
    ;; ecx = backlog (fixint)
    mov esi, symbol_value(rom_string_listen)
    cmp bl, socket_tag
    jne socket_type_error
    xchg ebx, ecx                   ; ebx := backlog, ecx := socket
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2                      ; untag backlog
    shr ecx, 8                      ; untag socket
    mov [scratchpad_start], ecx     ; socket file descriptor (untagged)
    mov [scratchpad_start + 4], ebx ; backlog (untagged)
    xor edx, edx
    mov ecx, scratchpad_start
    mov ebx, 4                      ; SYS_LISTEN
    call linux_socketcall
    mov eax, inert_tag
    jmp [ebp + cont.program]

app_accept:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_accept)
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    xor eax, eax
    mov [scratchpad_start], ebx
    mov [scratchpad_start + 4], eax
    mov [scratchpad_start + 8], eax
    mov ecx, scratchpad_start
    mov ebx, 5                       ; SYS_ACCEPT
    call linux_socketcall
    shl eax, 8
    mov al, socket_tag              ; tag file descriptor as socket
    jmp [ebp + cont.program]

app_setsockopt:
  .operate:
    mov esi, symbol_value(rom_string_setsockopt)
    call rn_count_parameters
    cmp ecx, 4
    jne socket_type_error
    mov edi, ebx
    ;; sockfd
    mov ebx, car(edi)
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    mov [scratchpad_start], ebx
    ;; level
    mov edi, cdr(edi)
    mov ebx, car(edi)
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2
    mov [scratchpad_start + 4], ebx
    ;; optname
    mov edi, cdr(edi)
    mov ebx, car(edi)
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2
    mov [scratchpad_start + 8], ebx
    ;; optval
    mov edi, cdr(edi)
    mov ebx, car(edi)
    cmp bl, bytevector_tag
    jne socket_type_error
    call rn_get_blob_data
    mov [scratchpad_start + 12], ebx
    mov [scratchpad_start + 16], ecx
    mov ecx, scratchpad_start
    mov ebx, 14                          ; SYS_SETSOCKOPT
    call linux_socketcall
    mov eax, inert_tag
    jmp [ebp + cont.program]

app_sendto:
  .A2:
    instrumentation_point
    mov edx, fixint_value(0);
  .A3:
    instrumentation_point
    mov edi, inert_tag
  .check:
    mov esi, symbol_value(rom_string_sendto)
    ;; sockfd
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    mov [scratchpad_start], ebx
    ;; buffer
    mov ebx, ecx
    cmp bl, bytevector_tag
    jne socket_type_error
    call rn_get_blob_data
    mov [scratchpad_start + 4], ebx
    mov [scratchpad_start + 8], ecx
    ;; flags
    mov ebx, edx
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2
    mov [scratchpad_start + 12], ebx
    ;; address
    mov ebx, edi
    cmp bl, inert_tag
    je .no_address
    cmp bl, bytevector_tag
    jne socket_type_error
    call rn_get_blob_data
    mov [scratchpad_start + 16], ebx
    mov [scratchpad_start + 20], ecx
  .execute:
    mov ecx, scratchpad_start
    mov ebx, 11                          ; SYS_SENDTO
    call linux_socketcall
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .no_address:
    xor eax, eax
    mov [scratchpad_start + 16], eax
    mov [scratchpad_start + 20], eax
    jmp .execute
  .operate:
    mov esi, symbol_value(rom_string_sendto)
    call rn_count_parameters
    cmp ecx, 2
    je .operate_2
    cmp ecx, 3
    je .operate_3
    cmp ecx, 4
    jne socket_type_error
  .operate_4:
    mov edi, ebx
    mov ebx, car(edi)
    mov edi, cdr(edi)
    mov ecx, car(edi)
    mov edi, cdr(edi)
    mov edx, car(edi)
    mov edi, cdr(edi)
    mov edi, car(edi)
    jmp .check
  .operate_3:
    mov edi, ebx
    mov ebx, car(edi)
    mov edi, cdr(edi)
    mov ecx, car(edi)
    mov edi, cdr(edi)
    mov edx, car(edi)
    jmp .A3
  .operate_2:
    mov edi, ebx
    mov ebx, car(edi)
    mov edi, cdr(edi)
    mov ecx, car(edi)
    jmp .A2

%define address_buffer_size ((scratchpad_end - scratchpad_start) - 32)

app_recvfrom:
  .A1:
    instrumentation_point
    mov ecx, fixint_value(0)
  .A2:
    instrumentation_point
    mov edx, fixint_value(8192)
  .A3:
    instrumentation_point
    mov esi, symbol_value(rom_string_recvfrom)
    ;; sockfd
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    mov [scratchpad_start], ebx
    ;; flags
    mov ebx, ecx
    call rn_fixintP_procz
    jnz socket_type_error
    sar ebx, 2
    mov [scratchpad_start + 12], ebx
    ;; buffer size
    mov ebx, edx
    call rn_fixintP_procz
    jnz socket_type_error
    mov ecx, ebx
    sar ecx, 2
    ;; reserve 256 bytes for the address
    add ecx, 256
    ;; maximum buffer size 64K
    cmp ecx, 65536
    ja socket_type_error
    ;; allocate buffer
    call rn_allocate_blob
    push eax
    mov ebx, eax
    call rn_get_blob_data
    sub ecx, address_buffer_size
    mov [scratchpad_start + 4], ebx
    mov [scratchpad_start + 8], ecx
    mov edx, scratchpad_start + 32
    mov eax, address_buffer_size
    mov [scratchpad_start + 16], edx           ; address buffer
    mov [scratchpad_start + 24], eax           ; address buffer size
    mov eax, scratchpad_start + 24
    mov [scratchpad_start + 20], eax           ; pointer to addres length
    ;; the syscall
    mov ecx, scratchpad_start
    mov ebx, 12                                ; SYS_RECVFROM
    call linux_socketcall
    ;; check message size
    mov edx, eax                               ; edx = message size
    mov ebx, [esp]
    call rn_get_blob_data
    sub ecx, address_buffer_size
    cmp edx, ecx
    ja .overflow
    ;; shring bytevector to fit the message
    mov ecx, edx
    mov ebx, [esp]
    call rn_shrink_last_blob
    ;; allocate new bytevector for the address
    mov ecx, [scratchpad_start + 24]
    cmp ecx, address_buffer_size
    ja .overflow
    call rn_allocate_blob
    push eax
    push dword nil_tag
    ;; copy data
    mov ebx, eax
    mov eax, [scratchpad_start + 16]
    cld
    call rn_copy_blob_data
    ;; allocate list (MESSAGE ADDRESS)
    call rn_cons
    push eax
    call rn_cons
    jmp [ebp + cont.program]
  .overflow:
    mov eax, err_buffer_overflow
    lea ebx, [4*ecx + 1]
    mov ecx, symbol_value(rom_string_recvfrom)
    jmp rn_error

;;
;; socket_prepare_sockaddr (native procedure)
;;
;; preconditions:   EBX = socket (tagged file descriptor)
;;                  ECX = bytevector
;;                  ESI = symbol for error reporting
;;
;; postconditions:  ECX = address of scratchpad_start
;;                  [scratchpad + 0] = sockfd (untagged)
;;                  [scratchpad + 4] = bytevector data
;;                  [scratchpad + 8] = bytevector length
;;
;; preserves:       ESI, EDI, EBP, ESP (call/ret)
;; clobbers:        EAX, EBX, ECX, EDX, EFLAGS
;;
socket_prepare_sockaddr:
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    mov [scratchpad_start], ebx
    mov ebx, ecx
    cmp bl, bytevector_tag
    jne socket_type_error
    call rn_get_blob_data
    mov [scratchpad_start + 4], ebx
    mov [scratchpad_start + 8], ecx
    mov ecx, scratchpad_start
    ret

;;
;; linux_socketcall (native procedure)
;;
;; preconditions:   EBX = socket call number (untagged, 1-17)
;;                  ECX = pointer to argument structure
;;
;; postconditions:  EAX = return value (untagged)
;;                  on error, divert to error continuation
;;
;; preserves:       ESI, EDI, EBP, ESP (call/ret)
;; clobbers:        EAX, EBX, ECX, EDX, EFLAGS
;;
linux_socketcall:
    mov eax, 0x66
    call call_linux
    test eax, eax
    js .error
    ret
  .error:
    neg eax                  ; EAX := negated errno
    lea ebx, [4*eax + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, esi
    jmp rn_error

;;
;; port interface
;;

app_socket_raw_input_port:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_socket_raw_input_port)
    call socket_tag_fd
    mov ecx, 6
    call rn_allocate
    mov [eax + bin_in.header], dword bin_in_header(6)
    mov [eax + bin_in.env], edx
    mov [eax + bin_in.close], dword primitive_value(linux_nop)
    mov [eax + bin_in.read], dword primitive_value(linux_read)
    mov [eax + bin_in.peek], dword primitive_value(linux_nop)
    mov [eax + bin_in.var0], edx ; dummy
    jmp [ebp + cont.program]

app_socket_raw_output_port:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_socket_raw_output_port)
    call socket_tag_fd
    mov ecx, 6
    call rn_allocate
    mov [eax + bin_out.header], dword bin_out_header(6)
    mov [eax + bin_out.env], edx
    mov [eax + bin_out.close], dword primitive_value(linux_nop)
    mov [eax + bin_out.write], dword primitive_value(linux_write)
    mov [eax + bin_out.flush], dword primitive_value(linux_nop)
    mov [eax + bin_out.var0], edx ; dummy
    jmp [ebp + cont.program]

socket_tag_fd:
    cmp bl, socket_tag
    jne socket_type_error
    mov edx, ebx
    shr edx, 8
    lea edx, [4*edx + 1]
    ret

app_close_socket:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_close_socket)
    cmp bl, socket_tag
    jne socket_type_error
    shr ebx, 8
    mov eax, 6
    call call_linux
    test eax, eax
    jnz linux_socketcall.error
    mov al, inert_tag
    jmp [ebp + cont.program]
