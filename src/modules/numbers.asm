;;;
;;; number.asm
;;;
;;; Kernel number features - fixint only.
;;;
;;; todo - overflow checks

;;
;; app_negate.A1 (continuation passing procedure)
;;
;; Implementation of (negate X) == (- 0 X).
;;
app_negate:
  .A1:
    call rn_integerP_procz
    jne .error
    test al, al
    jnz .bigint
    call rn_negate_fixint
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
;; (+) (+ N) (+ N N) (+ N N N)
;; (*) (* N) (* N N) (* N N N)
;; (- N N) (- N N N)
;; (div N N) (mod N N) (div-and-mod N N)
;;
app_plus:
  .A0:
    mov eax, fixint_value(0)
    jmp [ebp + cont.program]
  .A1:
    call rn_integerP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call .add_two_integers
    jmp [ebp + cont.program]
  .A3:
    push edx
    call .add_two_integers
    pop edx
    mov ebx, eax
    mov ecx, edx
    call .add_two_integers
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_C)
    jmp rn_error
  .operate:
    push dword .add_two_integers
    push dword symbol_value(rom_string_C)
    mov edi, fixint_value(0)
    jmp reduce_finite_list
  .add_two_integers:
    call rn_integerP_procz
    jne .type_error
    mov dl, al
    xchg ebx, ecx
    call rn_integerP_procz
    jne .type_error
    shl dl, 1
    or al, dl
    and eax, 0x3
    xchg ebx, ecx
    jmp [.jump_table + eax*4]
    align 16
  .jump_table:
    dd rn_fixint_plus_fixint
    dd rn_fixint_plus_bigint
    dd rn_bigint_plus_fixint
    dd rn_bigint_plus_bigint

app_minus:
  .A2:
    call .subtract_two_integers
    jmp [ebp + cont.program]
  .A3:
    push edx
    call .subtract_two_integers
    pop edx
    mov ebx, eax
    mov ecx, edx
    call .subtract_two_integers
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
    push dword .subtract_two_integers
    push dword symbol_value(rom_string__)
    jmp reduce_finite_list.list_ok
  .subtract_two_integers:
    call rn_integerP_procz
    jnz .type_error
    push ebx
    mov ebx, ecx
    call rn_integerP_procz
    jnz .type_error
    test al, al
    jnz .bigint
    call rn_negate_fixint
  .negated:
    mov ecx, eax
    pop ebx
    jmp app_plus.add_two_integers
  .bigint:
    call rn_negate_bigint
    jmp .negated
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string__)
    jmp rn_error
  .structure_error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string__)
    jmp rn_error

app_times:
  .A0:
    mov eax, fixint_value(1)
    jmp [ebp + cont.program]
  .A1:
    call rn_integerP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call check_fixint.app_2
    call rn_fixint_times_fixint
    jmp [ebp + cont.program]
  .A3:
    call check_fixint.app_2
    push edx
    call rn_fixint_times_fixint
    mov ebx, eax
    pop ecx
    call check_fixint.app_2
    call rn_fixint_times_fixint
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_X)
    jmp rn_error
  .operate:
    push dword .multiply_two_fixints
    push dword symbol_value(rom_string_X)
    mov edi, fixint_value(1)
    jmp reduce_finite_list
  .multiply_two_fixints:
    call check_fixint.app_2
    jmp rn_fixint_times_fixint
    mov eax, err_not_implemented
    jmp rn_error

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
    inc eax
    neg eax
    sub ecx, edx
    mov edx, ecx
    ret
  .negative_divisor:
    neg ebx
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
