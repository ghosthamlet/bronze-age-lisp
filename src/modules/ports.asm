;;;
;;; ports.asm
;;;
;;; Kernel port features.
;;;

%define txt_in.buffer          txt_out.var0
%define txt_in.bufpos          txt_out.var1
%define txt_in.state           txt_out.var2
%define txt_in.accum           txt_out.var3
%define txt_in.underlying_port txt_out.var4
%define txt_in.line            txt_out.var5
%define txt_in.column          (txt_out.var5 + 4)

%define txt_out.buffer          txt_out.var0
%define txt_out.usage           txt_out.var1
%define txt_out.underlying_port txt_out.var2

%define bin_out.buffer          bin_out.var0
%define bin_out.usage           bin_out.var1
%define bin_out.underlying_port bin_out.var2

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
    mov ebx, fixint_value(configured_default_buffer_size)  ; method argument
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
  .unsafe_io:
    mov eax, [ebx + bin_out.write]      ; method combiner
    mov edi, [ebx + bin_out.env]        ; env. for port method
    xchg ebx, ecx                       ; method argument
    jmp rn_combine
  .invalid_argument:
    mov eax, err_invalid_argument       ; error message
    mov ebx, ecx                        ; irritant argument
    mov ecx, [esi + operative.var2]     ; applicative's name
    jmp rn_error

;;
;; app_write_u8 (continuation passing procedure)
;;
;; preconditions: EBX = u8 argument
;;                ECX = binary output port object (optional argument)
;;                EBP = continuation
;;
app_write_u8:
  .A1:
    mov ecx, private_binding(rom_string_stdout)
    ; fallthrough
  .A2:
    call rn_u8P_procz
    jnz .invalid_argument
    xchg ebx, ecx
    mov eax, [ebx]
    cmp al, bin_out_header(0)
    jne .invalid_argument
    mov eax, [ebx + bin_out.write]      ; method combiner
    mov edi, [ebx + bin_out.env]        ; env. for port method
    xchg ebx, ecx                       ; method argument
    jmp rn_combine
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_write_u8)
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

;%include "textual-output-ports.asm"
;%include "textual-input-ports.asm"

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

app_open_raw_output_file:
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
    mov ecx, symbol_value(rom_string_open_binary_output_file)
    jmp rn_error

;;
;; get_linux_port (native procedure)
;;
;; preconditions:  EBX = port object
;;                 ECX = symbol for error reporting
;; postconditions: EAX = EBX = underlying linux port (with file descriptor)
;;                 ZF = 1 success
;;                 ZF = 0 failure
;;
;; preserves:      ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX, EFLAGS
;;
get_linux_port:
  .recurse:
    test bl, 3
    jnz .type_error
    mov eax, [ebx + txt_out.header]
    cmp al, txt_out_header(0)
    je .txt_out
    cmp al, txt_in_header(0)
    je .txt_in
    cmp al, bin_out_header(0)
    je .bin_out
    cmp al, bin_in_header(0)
    je .bin_in
  .type_error:
    mov eax, err_invalid_argument
    jmp rn_error
  .no:
    or al, 0xFF
    ret
  .txt_out:
    mov eax, [ebx + txt_out.write]
    cmp eax, primitive_value(app_open_utf_encoder.write_method)
    jne .no
    mov ebx, [ebx + txt_out.underlying_port]
    jmp .recurse
  .txt_in:
    mov eax, [ebx + txt_in.read]
    cmp eax, primitive_value(app_open_utf_decoder.read_method)
    jne .no
    mov ebx, [ebx + txt_in.underlying_port]
    jmp .recurse
  .bin_out:
  .bin_in:
    mov eax, [ebx + txt_out.env]
    xor al, 1
    test al, 3
    jne .no
  .has_file_descriptor:
    mov eax, ebx
    ret

;;
;; app_dup2 (continuation passing procedure)
;;
;; Interface to linux dup2() system call.
;;
;;   (dup2 PORT/INTEGER PORT/INTEGER) => #inert
;;
;; preconditions:  EBX = port object or nonnegative fixint
;;                 ECX = port object or nonnegative fixint
;;                 EBP = current continuation
;;
app_dup2:
  .A2:
    mov esi, symbol_value(rom_string_dup2)
    mov edi, ecx              ; EDI := 2nd arg
    call .get_fd              ; EBX := 1st fd
    xchg ebx, edi             ; EDI := 1st fd, EBX := 2nd arg
    call .get_fd              ; EBX := 2nd fd
    mov ecx, ebx              ; ECX := 2nd fd
    mov ebx, edi              ; EBX := 1st fd
    call rn_dup2
    mov eax, inert_tag
    jmp [ebp + cont.program]

  .get_fd:
    mov eax, ebx
    xor al, 1
    test eax, 0x80000003
    jnz .port
    ret
  .port:
    mov ecx, esi
    call get_linux_port
    jnz .invalid_argument
    mov ebx, [eax + txt_out.env]
    ret
  .invalid_argument:
    mov eax, err_invalid_argument
    jmp rn_error

;;
;; pred_terminal_port (native procedure)
;;
;; preconditions: EBX = object
;;                [ESI + operative.var0] = symbol for error reporting
;;                EBP = current continuation (for error reporting)
;;
;; postconditions: AL = 1 if EBX is a terminal port
;;                    = 0 if EBX is a port, but not a terminal port
;;                 raise error if EBX is not a port
;;
;; preserves: ESI, EDI, EBP
;; clobbers: EAX, EBX, EDX, EFLAGS
;;
;; A port is a terminal port, if it is
;;
;;     1) binary input or output port which wraps a linux
;;        file descriptor FD, and ioctl(FD, TCGETS, ...) = 0.
;;
;;  or 2) UTF-8 encoder or decoder port on top of a terminal port
;;
pred_terminal_port:
    ;; ebx = port object
    mov ecx, [esi + operative.var0]
    call get_linux_port
    jz .file_descriptor
    xor eax, eax
    ret
  .file_descriptor:
    mov edx, eax
    mov eax, [edx + bin_out.var0]  ; cached isatty flag
    cmp al, boolean_value(0)
    je .done_tagged
    mov ebx, [edx + txt_out.env]
    call rn_isatty
    mov [edx + bin_out.var0], eax
  .done_tagged:
    mov al, ah
    ret

;;
;; app_tcgetattr ... (tcgetattr PORT) => BYTEVECTOR
;; app_tcsetattr ... (tcsetattr PORT BYTEVECTOR)
;; app_tc_cbreak_noecho (tc-cbreak-noecho BYTEVECTOR) => BYTEVECTOR
;;
app_tcgetattr:
  .A1:
    mov ecx, symbol_value(rom_string_tcgetattr)
    call get_linux_port
    jne .error
    mov ebx, [eax + bin_out.env]
    call rn_tcgets
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    jmp rn_error

app_tcsetattr:
  .A2:
    mov edx, ecx
    mov ecx, symbol_value(rom_string_tcsetattr)
    cmp dl, bytevector_tag
    jne .type_error
    call get_linux_port
    jnz .type_error
    mov ebx, [eax + bin_out.env]
    mov ecx, edx
    call rn_tcsets
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ebx, edx
    jmp rn_error

app_tc_cbreak_noecho:
  .A1:
    mov ecx, symbol_value(rom_string_tc_cbreak_noecho)
    cmp bl, bytevector_tag
    jne .type_error
    mov esi, ebx
    call rn_get_blob_data
    call rn_allocate_blob
    mov edi, eax
    mov ebx, eax
    mov eax, esi
    call rn_copy_blob_data
    call rn_tc_cbreak_noecho
    mov eax, edi
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    jmp rn_error

;;
;; app_char_readyP
;;
;; Implementation of (char-ready? [PORT])
;;
app_char_readyP:
  .A0:
    mov ebx, private_binding(rom_string_stdin)
  .A1:
    mov ecx, symbol_value(rom_string_char_readyP)
    mov esi, ebx
    call get_linux_port
    jnz .type_error
    mov edi, eax
    mov eax, [esi + txt_in.read]
    cmp eax, primitive_value(app_open_utf_decoder.read_method)
    jne .ask_the_system
  .ask_the_decoder:
    mov ecx, [esi + txt_in.accum]
    cmp cl, char_tag
    jz .yes
    push .yes
    call txt_in_try_buffer
  .ask_the_system:
    mov ebx, [edi + bin_out.env]
    call rn_file_descriptor_ready
    jmp [ebp + cont.program]
  .yes:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    jmp rn_error
