
app_char_Ginteger:
  .A1:
    instrumentation_point
    ;; ebx = argument
    ;; ebp = continuation
    cmp bl, char_tag
    jne .error
    shr ebx, 6
    mov eax, ebx
    jmp [ebp + cont.program]
  .error:
    mov ebx, eax
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_char_Ginteger)
    jmp rn_error

app_integer_Gchar:
  .A1:
    instrumentation_point
    mov ecx, symbol_value(rom_string_integer_Gchar)
    ;; ebx = argument
    ;; ebp = continuation
    ;; check if it is fixint
    mov al, bl
    and al, 3
    xor al, 1
    jnz .invalid_argument
    ;; check if it is a valid Unicode code point
    ;;  - unicode planes 0-16 are valid (0 ... 0x10FFFF)
    ;;  - invalid Byte Order Mark is not valid (0xFFFE)
    ;;  - the range 0xD800 ... 0xDFF is reserved for UTF-16 surrogate pairs
    cmp ebx, fixint_value(0x10FFFF)
    ja .invalid_codepoint
    cmp ebx, fixint_value(0xFFFE)
    je .invalid_codepoint
    mov eax, ebx
    xor eax, fixint_value(0xD800)
    test eax, ~fixint_value(0xDFFF ^ 0xD800)
    jz .invalid_codepoint
    shl ebx, 6
    or bl, char_tag
    mov eax, ebx
    jmp [ebp + cont.program]
  .invalid_argument:
    mov eax, err_invalid_argument
    jmp rn_error
  .invalid_codepoint:
    mov eax, err_invalid_codepoint
    jmp rn_error

;;
;; (char-digit? CHAR)
;; (char-digit? CHAR BASE)
;;
;; (char->digit CHAR)
;; (char->digit CHAR BASE)
;;

app_char_digitP:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_char_digitP)
    mov ecx, fixint_value(10)
    jmp .start
  .A2:
    instrumentation_point
    mov esi, symbol_value(rom_string_char_digitP)
    call char_digit_error.check_base
  .start:
    cmp bl, char_tag
    jne char_digit_error.char
    mov eax, ebx
    call char_digit_aux
    cmp al, boolean_tag
    jne .digit
    jmp [ebp + cont.program]
  .digit:
    cmp eax, ecx
    mov eax, boolean_tag
    setb ah
    jmp [ebp + cont.program]

app_char_Gdigit:
  .A1:
    instrumentation_point
    mov esi, symbol_value(rom_string_char_Gdigit)
    mov ecx, fixint_value(10)
    jmp .start
  .A2:
    instrumentation_point
    mov esi, symbol_value(rom_string_char_Gdigit)
    call char_digit_error.check_base
  .start:
    cmp bl, char_tag
    jne char_digit_error.char
    mov eax, ebx
    call char_digit_aux
    cmp al, boolean_tag
    je char_digit_error.not_a_digit
    cmp eax, ecx
    jae char_digit_error.not_a_digit
    jmp [ebp + cont.program]

char_digit_error:
  .check_base:
    mov edx, ecx
    xor dl, 1
    test dl, 3
    jnz .invalid_base
    cmp ecx, fixint_value(2)
    jb .invalid_base
    cmp ecx, fixint_value(36)
    ja .invalid_base
    ret
  .char:
    mov ecx, esi
    mov eax, err_invalid_argument
    jmp rn_error
  .not_a_digit:
    mov ecx, symbol_value(rom_string_char_Gdigit)
    mov eax, err_not_a_digit
    jmp rn_error
  .invalid_base:
    mov ecx, esi
    mov eax, err_invalid_base
    jmp rn_error
    mov edx, err_invalid_base

;;
;; char_digit_aux (native procedure)
;;
;; Compute numeric value of a digit.
;;
;;    '0' ... '9'  =>  0 ...  9
;;    'a' ... 'z'  => 10 ... 35
;;    'A' ... 'Z'  => 10 ... 35
;;
;; preconditions:  EAX = input character (tagged value)
;;
;; postconditions: EAX = digit value (tagged fixint), if the input is a digit
;;                 EAX = #f, if the input is not a digit
;;                 EBX = input character, if it is not a digit (for error reporting)
;;
;; clobbers:       EAX, EBX, EDX, EFLAGS
;; preserves:      ECX, ESI, EDI, EBP
;;
char_digit_aux:
    cmp eax, char_value('z')
    ja .not_a_digit
    movzx ebx, ah
    shr bl, 5
    mov dx, [.bounds + 4*ebx]
    cmp ah, dl
    jb .not_a_digit
    cmp ah, dh
    ja .not_a_digit
    sub ah, [.bounds + 4*ebx + 2]
    shr eax, 6
    or al, fixint_tag
    ret
  .not_a_digit:
    mov ebx, eax
    mov eax, boolean_value(0)
    ret
    align 4
  .bounds:
    db   1,   0,        0, 0
    db '0', '9', '0' -  0, 0
    db 'A', 'F', 'A' - 10, 0
    db 'a', 'f', 'a' - 10, 0

app_digit_Gchar:
  .A1:
    instrumentation_point
    mov ecx, fixint_value(10)
  .A2:
    instrumentation_point
    mov esi, symbol_value(rom_string_digit_Gchar)
    call char_digit_error.check_base
    mov eax, ebx
    xor al, 1
    test al, 3
    jne .error
    cmp ebx, fixint_value(0)
    jl .error
    cmp ebx, ecx
    jge .error
    mov eax, ebx
    shr eax, 2
    cmp eax, 10
    jb .decimal
    add al, 'A' - '0' - 10
  .decimal:
    add al, '0'
    shl eax, 8
    mov al, char_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, esi
    jmp rn_error
