;;;
;;; debug.asm
;;;
;;; Support macros and procedures for debugging the interpreter.
;;;

;;
;; rn_trace FLAG, KEY, FORMAT1, REG1, FORMAT2, REG2, ...
;;
;; If FLAG is 1, the macro expands to piece
;; of assembly code which prints a trace line to stderr in
;; the form
;;
;;  KEY TEXT1 TEXT2 ...
;;
;; where KEY is a string
;;       FORMAT is the token 'lisp' or 'hex'
;;       REG is a register name
;;       TEXT is textual form of the value of REG
;;
;; If FLAG is 0, the macro expands to nothing
;;
%macro rn_trace 2-*
  %if (%1 == 1)
    pusha
    mov al, '{'
    call rn_trace_print_char
    %assign i 0
    %strlen len %2
    %rep len
      %substr chr %2 (i + 1)
      mov al, chr
      call rn_trace_print_char
      %assign i (i + 1)
    %endrep
    mov al, '}'
    call rn_trace_print_char
    popa
  %rotate 2
  %rep ((%0 - 2) / 2)
    pusha
    mov ebx, %2
    mov eax, ' '
    call rn_trace_print_char
    mov eax, ebx
    call rn_trace_print_%1
    popa
    %rotate 2
  %endrep
    pusha
    mov al, 10
    call rn_trace_print_char
    popa
  %endif
%endmacro

;;
;; rn_trace_print_char (native procedure)
;;
;; Prints ASCII character to stderr.
;;
;; precondition: EAX = character code (0-127)
;; preserves:    EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:     EFLAGS
;;
rn_trace_print_char:
    pusha
    mov eax, 4
    mov ebx, 2
    lea ecx, [esp + 28]
    mov edx, 1
    int 0x80
    popa
    ret

;;
;; rn_trace_print_buf (native procedure)
;;
;; Prints ASCII string to stderr.
;;
;; preconditions: EBX = buffer address
;;                ECX = buffer length
;; preserves:     EAX, EBX, ECX, EDX, ESI, EDI
;;
rn_trace_print_buf:
    pusha
    mov edx, ecx
    mov ecx, ebx
    mov eax, 4
    mov ebx, 2
    int 0x80
    popa
    ret

;;
;; rn_trace_print_hex (native procedure)
;;
;; Prints 32-bit number in hexadecimal notation to stderr.
;;
;; preconditions: EAX = number
;; preserves:     EAX, EBX, ECX, EDX, ESI, EDI
;;
rn_trace_print_hex:
    pusha
    mov ebx, .hex_digits
    mov ecx, 2
    call rn_trace_print_buf
    mov ecx, eax
    xor eax, eax
  %assign i 28
  %rep 8
    mov ebx, ecx
    shr ebx, i
    and ebx, 15
    mov al, [.hex_digits + 2 + ebx]
    call rn_trace_print_char
  %assign i (i - 4)
  %endrep
    popa
    ret
  .hex_digits:
    db '#x0123456789ABCDEF'

;;
;; rn_trace_print_lisp (native procedure)
;;
;; Prints lisp value to stderr. The printer is simplified
;; in the following sense:
;;   - fixints are printed in hexadecimal notation
;;   - cycles cause infinite loop
;;
;; preconditions: EBX = lisp value
;; preserves:     EDX, ESI, EDI
;; clobbers:      EAX, EBX, ECX
;;
rn_trace_print_lisp:
    mov eax, ebx
    ;call rn_trace_print_hex
    test ebx, ebx
    jz .nonlisp
    test bl, 3
    jz .pointer
    jp .case.pair
    test bl, 2
    jz .case.fixint
    jmp .tagged
  .nonlisp:
    mov al, '?'
    call rn_trace_print_char
    mov eax, ebx
    jmp rn_trace_print_hex
  .pointer:
    cmp eax, lisp_rom_base
    jb .nonlisp
    cmp eax, lisp_heap_area_end
    jae .nonlisp
    mov eax, [ebx]
    mov ecx, eax
    xor cl, 1
    test cl, 3
    jnz .nonlisp
    cmp al, cont_header(0)
    je .case.cont
    cmp al, environment_header(0)
    je .case.environment
    cmp al, encapsulation_header(0)
    je .case.encapsulation
    cmp al, operative_header(0)
    je .case.operative
    cmp al, applicative_header(0)
    je .case.applicative
    cmp al, (error_header & 0xFF)
    je .case.error_object
    cmp al, bigint_header(0)
    je .case.bigint
    jmp .case.other_header
  .tagged:
    cmp bl, boolean_tag
    je .case.boolean
    cmp bl, char_tag
    je .case.char
    cmp bl, nil_tag
    je .case.nil
    cmp bl, inert_tag
    je .case.inert
    cmp bl, ignore_tag
    je .case.ignore
    cmp bl, eof_tag
    je .case.eof
    cmp bl, symbol_tag
    je .case.symbol
    cmp bl, string_tag
    je .case.string
    cmp bl, keyword_tag
    je .case.keyword
    cmp bl, primitive_tag
    je .case.primitive
    jmp .case.other
  .case.keyword:
    mov eax, ebx
    mov ebx, .keyword_prefix
    mov ecx, 2
    call rn_trace_print_buf
    mov ebx, eax
  .case.symbol:
    call rn_get_blob_data
    jmp rn_trace_print_buf
  .case.string:
    mov al, '"'
    call rn_trace_print_char
    call rn_get_blob_data
    call rn_trace_print_buf
    mov al, '"'
    jmp rn_trace_print_char
  .case.fixint:
    test ebx, ebx
    js .negative
    mov eax, ebx
    shr eax, 2
    jmp rn_trace_print_hex
  .negative:
    mov al, '-'
    call rn_trace_print_char
    mov eax, ebx
    sar eax, 2
    neg eax
    jmp rn_trace_print_hex
  .case.pair:
    mov eax, '('
    call rn_trace_print_char
  .tail:
    push dword cdr(ebx)
    mov ebx, car(ebx)
    call rn_trace_print_lisp
    pop ebx
    cmp ebx, nil_tag
    je .nil
    test bl, 3
    jz .dot
    jnp .dot
    mov eax, ' '
    call rn_trace_print_char
    jmp .tail
  .dot:
    push ebx
    mov ebx, .list_dot
    mov ecx, 3
    call rn_trace_print_buf
    pop ebx
    call rn_trace_print_lisp
  .nil:
    mov eax, ')'
    jmp rn_trace_print_char
  .case.boolean:
    shr ebx, 7
    add ebx, .bool_string
    mov ecx, 2
    jmp rn_trace_print_buf
  .case.nil:
    mov ebx, .nil_string
    mov ecx, 2
    jmp rn_trace_print_buf
  .case.inert:
    mov ebx, .inert_string
    mov ecx, 6
    jmp rn_trace_print_buf
  .case.ignore:
    mov ebx, .ignore_string
    mov ecx, 7
    jmp rn_trace_print_buf
  .case.eof:
    mov ebx, .eof_string
    mov ecx, 6
    jmp rn_trace_print_buf
  .case.char:
    mov al, 0x5C
    call rn_trace_print_char
    mov eax, ebx
    shr eax, 8
    jmp rn_trace_print_hex
  .case.other_header:
    mov eax, ebx
    mov ebx, .header_string
    mov ecx, 9
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_hex
    mov al, ' '
    call rn_trace_print_char
    mov eax, [ebx]
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.other:
    shr eax, 2
    call rn_trace_print_hex
    mov eax, ebx
    call rn_trace_print_hex
    mov ebx, .unknown_message
    mov ecx, 5
    jmp rn_trace_print_buf
  .case.port:
    mov eax, ebx
    mov ebx, .port_string
    mov ecx, 7
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.cont:
    mov eax, ebx
    mov ebx, .continuation_string
    mov ecx, 15
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.encapsulation:
    mov eax, ebx
    mov ebx, .encapsulation_string
    mov ecx, 16
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.environment:
    mov eax, ebx
    mov ebx, .environment_string
    mov ecx, 16
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.primitive:
    mov eax, ebx
    mov ebx, .primitive_string
    mov ecx, 12
    call rn_trace_print_buf
    shr eax, 8
    add eax, program_segment_base
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.operative:
    mov eax, ebx
    mov ebx, .operative_string
    mov ecx, 12
    call rn_trace_print_buf
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.applicative:
    mov eax, ebx
    mov ebx, .applicative_string
    mov ecx, 14
    call rn_trace_print_buf
    call rn_trace_print_hex
    mov al, ']'
    jmp rn_trace_print_char
  .case.error_object:
    push ebx
    mov ebx, .error_object_string
    mov ecx, 8
    call rn_trace_print_buf
    mov eax, [esp]
    call rn_trace_print_hex
    mov al, ' '
    call rn_trace_print_char
    mov edx, [esp]
    mov ebx, [edx + error.message]
    call rn_trace_print_lisp
    mov al, ' '
    call rn_trace_print_char
    mov edx, [esp]
    mov ebx, [edx + error.irritants]
    call rn_trace_print_lisp
    mov al, 10
    call rn_trace_print_char
    mov al, ' '
    call rn_trace_print_char
    mov al, ' '
    call rn_trace_print_char
    mov al, ' '
    call rn_trace_print_char
    mov edx, [esp]
    mov ebx, [edx + error.source]
    call rn_trace_print_lisp
    mov al, ' '
    call rn_trace_print_char
    mov edx, [esp]
    mov ebx, [edx + error.cc]
    call rn_trace_print_lisp
    mov al, ' '
    call rn_trace_print_char
    mov edx, [esp]
    mov ebx, [edx + error.address]
    call rn_trace_print_lisp
    pop edx
    mov al, ']'
    jmp rn_trace_print_char
  .case.bigint:
    push ebx
    mov ebx, .bigint_string
    mov ecx, 9
    call rn_trace_print_buf
    pop ebx
    mov eax, ebx
    call rn_trace_print_hex
    mov al, ' '
    call rn_trace_print_char
    mov eax, [ebx]
    shr eax, 8
    call rn_trace_print_hex
    mov al, ' '
    call rn_trace_print_char
    mov eax, [ebx + bigint.digit0]
    call rn_trace_print_hex
    mov ecx, [ebx + bigint.header]
    shr ecx, 8
    sub ecx, 2
    push edx
    lea edx, [ebx + bigint.digit1]
  .case.bigint.L1:
    mov eax, [edx]
    add edx, 4
    call rn_trace_print_hex
    loop .case.bigint.L1
    pop edx
    mov al, ']'
    jmp rn_trace_print_char

  .header_string db '#[header '
  .unknown_message db '<???>'
  .list_dot db ' . '
  .bool_string db '#f#t'
  .keyword_prefix db '#:'
  .nil_string db '()'
  .inert_string db '#inert'
  .ignore_string db '#ignore'
  .eof_string db '#[eof]'
  .port_string db '#[port '
  .encapsulation_string db '#[encapsulation '
  .continuation_string db '#[continuation '
  .environment_string db '#[environment '
  .null_pointer_string db "<NULL>"
  .primitive_string db '#[primitive '
  .operative_string db '#[operative '
  .applicative_string db '#[applicative '
  .error_object_string db '#[error '
  .bigint_string db '#[bigint '

;;
;; rn_exit
;;
;; Prints final lisp value and terminates the program.
;;
;; preconditions: eax = lisp value
;;
rn_exit:
    mov ebx, .msg
    mov ecx, 9
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_lisp
    mov eax, 10
    call rn_trace_print_char
    mov eax, 1
    mov ebx, 0
    int 0x80
  .msg: db 10, "RESULT: "

;;
;; rn_fatal
;;
;; Fatal error handler for development.
;;
;; Prints error message, irritants and registers and terminates
;; the program with exit code 1 (EXIT_FAILURE).
;;
;; preconditions: EAX = error message (lisp string)
;;                EBX = irritant (lisp object)
;;                ECX = procedure which detected the error (lisp symbol)
;;
rn_fatal:
    push ebp
    push edi
    push esi
    push edx
    push ecx
    push ebx
    push eax
    push ecx
    push ebx
    mov ebx, .regmsg
    mov ecx, 7
    call rn_trace_print_buf
    mov ebx, eax
    call rn_trace_print_lisp
    mov al, 10
    call rn_trace_print_char
    pop ebx
    call rn_trace_print_lisp
    mov al, 10
    call rn_trace_print_char
    pop ebx
    cmp bl, symbol_tag
    jne .no_symbol
    call rn_trace_print_lisp
    mov al, 10
    call rn_trace_print_char
  .no_symbol:
%rep 7
    mov al, 32
    call rn_trace_print_char
    pop eax
    call rn_trace_print_hex
%endrep
    mov al, 10
    call rn_trace_print_char
    mov eax, 1
    mov ebx, 1
    int 0x80
  .regmsg:
    db "ERROR: "
