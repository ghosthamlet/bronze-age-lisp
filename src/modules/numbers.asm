;;;
;;; number.asm
;;;
;;; Kernel number features - fixint only.
;;;
;;; TODO: cyclic argument lists
;;;       bigint division
;;;        min, max

;;
;; app_negate.A1 (continuation passing procedure)
;;
;; Implementation of (negate X) == (- 0 X).
;;
app_negate:
  .A1:
    call rn_numberP_procz
    jne .error
    cmp al, 1
    ja .infinite
    je .bigint
    call rn_negate_fixint
    jmp [ebp + cont.program]
  .infinite:
    mov eax, ebx
    xor eax, 0xFFFFFE00
    jmp [ebp + cont.program]
  .bigint:
    call rn_negate_bigint
    jmp [ebp + cont.program]
  .error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_negate)
    push app_negate.error
    jmp rn_error

;;
;; reduce_finite_list (native procedure)
;;
;; preconditions:  EBX = argument list
;;                 EDI = initial value
;;                 [ESP] = symbol for error reporting
;;                 [ESP + 4] = operator
;;
reduce_finite_list:
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .structure_error
    test ecx, ecx
    jnz .structure_error
  .list_ok:
    mov ecx, edx
    jecxz .done
    pop eax
  .next:
    push ecx
    mov ebx, edi
    mov ecx, car(esi)
    mov esi, cdr(esi)
    call [esp + 4]
    mov edi, eax
    pop ecx
    loop .next
    mov eax, edi
  .done:
    pop edx
    jmp [ebp + cont.program]
  .structure_error:
    mov eax, err_invalid_argument_structure
    mov ebx, esi
    pop ecx
    push dword reduce_finite_list.structure_error
    jmp rn_error

check_fixint:
  .app_3:
    xchg ebx, edx
    call rn_fixintP_procz
    jne .type_error
    xchg ebx, edx
  .app_2:
    xchg ebx, ecx
    call rn_fixintP_procz
    jne .type_error
    xchg ebx, ecx
  .app_1:
    call rn_fixintP_procz
    jne .type_error
    ret
  .type_error:
     mov ecx, inert_tag ;[eax + applicative.name]
     mov eax, err_not_a_number
     jmp rn_error

;;
;; (+) (+ N) (+ N N) (+ N N N) (+ . <finite list>)
;;
app_plus:
  .A0:
    mov eax, fixint_value(0)
    jmp [ebp + cont.program]
  .A1:
    call rn_numberP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call .add_two_numbers
    jmp [ebp + cont.program]
  .A3:
    push edx
    call .add_two_numbers
    pop edx
    mov ebx, eax
    mov ecx, edx
    call .add_two_numbers
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_C)
    jmp rn_error
  .operate:
    push dword .add_two_numbers
    push dword symbol_value(rom_string_C)
    mov edi, fixint_value(0)
    jmp reduce_finite_list
  .add_two_numbers:
    call rn_numberP_procz
    jne .type_error
    mov dl, al
    xchg ebx, ecx
    call rn_numberP_procz
    jne .type_error
    shl dl, 2
    or al, dl
    and eax, 0xF
    xchg ebx, ecx
    jmp [.jump_table + eax*4]
  .finite_plus_infinite:
    mov eax, ecx
    ret
  .infinite_plus_finite:
    mov eax, ebx
    ret
  .infinite_plus_infinite:
    cmp ebx, ecx
    jne .undefined
    mov eax, ebx
    ret
  .undefined:
    mov eax, err_undefined_arithmetic_operation
    mov ecx, symbol_value(rom_string_C)
    jmp rn_error
    align 16
  .jump_table:
    dd rn_fixint_plus_fixint
    dd rn_fixint_plus_bigint
    dd .finite_plus_infinite
    dd 0xDEAD0A10
    dd rn_bigint_plus_fixint
    dd rn_bigint_plus_bigint
    dd .finite_plus_infinite
    dd 0xDEAD0A20
    dd .infinite_plus_finite
    dd .infinite_plus_finite
    dd .infinite_plus_infinite
    dd 0xDEAD0A30
    dd 0xDEAD0A40
    dd 0xDEAD0A50
    dd 0xDEAD0A60
    dd 0xDEAD0A70

;;
;; (- N N) (- N N N) (- N . <finite list>
;;
app_minus:
  .A2:
    call .subtract_two_numbers
    jmp [ebp + cont.program]
  .A3:
    push edx
    call .subtract_two_numbers
    pop edx
    mov ebx, eax
    mov ecx, edx
    call .subtract_two_numbers
    jmp [ebp + cont.program]
  .operate:
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .structure_error
    test ecx, ecx
    jnz .structure_error
    cmp edx, 1
    jbe .structure_error
    dec edx
    mov edi, car(esi)
    mov esi, cdr(esi)
    push dword .subtract_two_numbers
    push dword symbol_value(rom_string__)
    jmp reduce_finite_list.list_ok
  .subtract_two_numbers:
    call rn_numberP_procz
    jnz .type_error
    push ebx
    mov ebx, ecx
    call rn_numberP_procz
    jnz .type_error
    cmp al, 1
    je .bigint
    ja .infinity
    call rn_negate_fixint
  .negated:
    mov ecx, eax
    pop ebx
    jmp app_plus.add_two_numbers
  .bigint:
    call rn_negate_bigint
    jmp .negated
  .infinity:
    mov eax, ebx
    xor eax, 0xFFFFFE00
    jmp .negated
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string__)
    jmp rn_error
  .structure_error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string__)
    jmp rn_error
;;
;; (*) (* N) (* N N) (* N N N) (* . <finite list>)
;;
app_times:
  .A0:
    mov eax, fixint_value(1)
    jmp [ebp + cont.program]
  .A1:
    call rn_numberP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call .multiply_two_numbers
    jmp [ebp + cont.program]
  .A3:
    push edx
    call .multiply_two_numbers
    pop edx
    mov ebx, eax
    mov ecx, edx
    call .multiply_two_numbers
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_X)
    jmp rn_error
  .operate:
    push dword .multiply_two_numbers
    push dword symbol_value(rom_string_X)
    mov edi, fixint_value(1)
    jmp reduce_finite_list
  .multiply_two_numbers:
    call rn_numberP_procz
    jne .type_error
    mov dl, al
    xchg ebx, ecx
    call rn_numberP_procz
    jne .type_error
    shl dl, 2
    or al, dl
    and eax, 0xF
    xchg ebx, ecx
    jmp [.jump_table + eax*4]
  .fixint_times_infinite:
    xchg ebx, ecx
  .infinite_times_fixint:
    cmp ecx, fixint_value(0)
    je .undefined
  .transfer_sign:
    mov eax, ebx
    test ecx, ecx
    jns .keep_sign
    xor eax, 0xFFFFFE00
  .keep_sign:
    ret
  .bigint_times_infinite:
    xchg ebx, ecx
  .infinite_times_bigint:
    mov eax, [ecx]
    shr eax, 8
    mov ecx, [ecx + 4*eax - 4]
    jmp .transfer_sign
  .undefined:
    mov eax, err_undefined_arithmetic_operation
    mov ecx, symbol_value(rom_string_X)
    jmp rn_error
    align 16
  .jump_table:
    dd rn_fixint_times_fixint
    dd rn_fixint_times_bigint
    dd .fixint_times_infinite
    dd 0xDEAD0B10
    dd rn_bigint_times_fixint
    dd rn_bigint_times_bigint
    dd .bigint_times_infinite
    dd 0xDEAD0B20
    dd .infinite_times_fixint
    dd .infinite_times_bigint
    dd .transfer_sign
    dd 0xDEAD0B30
    dd 0xDEAD0B40
    dd 0xDEAD0B50
    dd 0xDEAD0B60
    dd 0xDEAD0B70

;; (div N N) (mod N N) (div-and-mod N N) for fixint N
;; TODO: bigints
app_div:
  .A2:
    call check_fixint.app_2
    sar ebx, 2
    sar ecx, 2
    call scheme_div_mod
    lea eax, [4*eax + 1]
    jmp [ebp + cont.program]

app_mod:
  .A2:
    call check_fixint.app_2
    sar ebx, 2
    sar ecx, 2
    call scheme_div_mod
    lea eax, [4*edx + 1]
    jmp [ebp + cont.program]

app_div_and_mod:
  .A2:
    call check_fixint.app_2
    sar ebx, 2
    sar ecx, 2
    call scheme_div_mod
    lea ebx, [4*eax + 1]
    lea edx, [4*edx + 1]
    push edx
    push nil_tag
    call rn_cons
    push ebx
    push eax
    call rn_cons
    jmp [ebp + cont.program]

scheme_div_mod:
    ;; pre: ebx = dividend
    ;;      ecx = divisor
    ;; post: eax = quotient
    ;;       edx = remainder
    test ecx, ecx
    jz .error
    js .negative_divisor
  .positive_divisor:
    test ebx, ebx
    js .negative_dividend
  .positive_divident:
    xor edx, edx
    mov eax, ebx
    div ecx
    ret
  .negative_dividend:
    neg ebx
    xor edx, edx
    mov eax, ebx
    div ecx
    test edx, edx
    jz .no_adjustment
    inc eax
    sub ecx, edx
    mov edx, ecx
  .no_adjustment:
    neg eax
    ret
  .negative_divisor:
    neg ecx
    call .positive_divisor
    neg eax
    ret
  .error:
    mov ecx, ignore_tag ;[eax + applicative.name]
    mov eax, err_division_by_zero
    jmp rn_error

;;
;; (number-digits NUMBER BASE)
;;

%if (configured_reader_and_printer)
app_number_digits:
  .A2:
    ;; ebx = nonnegative fixint
    ;; ecx = base (fixint), 2 <= base <= 36
    ;; ebp = continuation
    mov eax, ebx
    mov ebx, ecx
    shr eax, 2
    shr ebx, 2
    lea ecx, [scratchpad_end]
  .next_digit:
    xor edx, edx
    div ebx
    cmp dl, 10
    jb .decimal
    add dl, 'A' - 10 - '0'
  .decimal:
    add dl, '0'
    dec ecx
    mov [ecx], dl
    test eax, eax
    jnz .next_digit
  .done:
    mov edx, ecx
    mov ecx, scratchpad_end
    sub ecx, edx
    call rn_allocate_blob
    mov ebx, eax
    mov eax, edx
    call rn_copy_blob_data
    mov eax, ebx
    mov al, string_tag
    jmp [ebp + cont.program]
%endif
