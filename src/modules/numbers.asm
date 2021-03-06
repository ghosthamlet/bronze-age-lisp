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
    instrumentation_point
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

;;
;; app_min_max
;;
;; Implementation of (min ...) and (max ...)
;;
;;  preconditions: ESI = operative closure
;;                 [ESI + operative.var0] = binary operator implementation
;;                 [ESI + operative.var1] = neutral value
;;                 [ESI + operative.var2] = symbol for error reporting
;;
app_min_max:
  .A0:
    instrumentation_point
    mov eax, [esi + operative.var1]
    jmp [ebp + cont.program]
  .A1:
    instrumentation_point
    call rn_numberP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    instrumentation_point
    call dword [esi + operative.var0]
    jmp [ebp + cont.program]
  .A3:
    instrumentation_point
    push edx
    call dword [esi + operative.var0]
    pop edx
    mov ebx, eax
    mov ecx, edx
    call dword [esi + operative.var0]
    jmp [ebp + cont.program]
  .operate:
    push dword [esi + operative.var0]
    push dword [esi + operative.var2]
    mov edi, [esi + operative.var1]
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz reduce_finite_list.structure_error
    jmp reduce_finite_list.list_ok
  .type_error:
    mov eax, err_not_a_number
    mov ecx, [esi + operative.var2]
    jmp rn_error

  .do_min:
    push ebx
    push ecx
    call rn_integer_compare
    pop ebx
    pop ecx
    jmp .select
  .do_max:
    push ebx
    push ecx
    call rn_integer_compare
    pop ecx
    pop ebx
  .select:
    test eax, eax
    js .negdiff
    mov eax, ebx
    ret
  .negdiff:
    mov eax, ecx
    ret

;;
;; (+) (+ N) (+ N N) (+ N N N) (+ . <finite list>)
;;
app_plus:
  .A0:
    instrumentation_point
    mov eax, fixint_value(0)
    jmp [ebp + cont.program]
  .A1:
    instrumentation_point
    call rn_numberP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    instrumentation_point
    call .add_two_numbers
    jmp [ebp + cont.program]
  .A3:
    instrumentation_point
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
    instrumentation_point
    call .subtract_two_numbers
    jmp [ebp + cont.program]
  .A3:
    instrumentation_point
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
    instrumentation_point
    mov eax, fixint_value(1)
    jmp [ebp + cont.program]
  .A1:
    instrumentation_point
    call rn_numberP_procz
    jnz .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    instrumentation_point
    call .multiply_two_numbers
    jmp [ebp + cont.program]
  .A3:
    instrumentation_point
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
    instrumentation_point
    call check_div_args
    jz .big
  .fix:
    sar ebx, 2
    sar ecx, 2
    call scheme_div_mod
    lea eax, [4*eax + 1]
    jmp [ebp + cont.program]
  .big:
    mov edi, .continue
  .fallback:
    push ecx
    push nil_tag
    call rn_cons
    push ebx
    push eax
    call rn_cons
    mov ebx, eax
    mov ecx, -4
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(4)
    mov [eax + cont.program], edi
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], dword inert_tag
    mov ebp, eax
    mov eax, private_binding(rom_string_general_div_and_mod)
    mov edi, private_binding(rom_string_private_environment)
    jmp rn_combine
  .continue:
    mov ebp, [ebp + cont.parent]
    mov eax, car(eax)
    jmp [ebp + cont.program]

app_mod:
  .A2:
    instrumentation_point
    call check_div_args
    jz .big
    sar ebx, 2
    sar ecx, 2
    call scheme_div_mod
    lea eax, [4*edx + 1]
    jmp [ebp + cont.program]
  .big:
    mov edi, .continue
    jmp app_div.fallback
  .continue:
    mov ebp, [ebp + cont.parent]
    mov eax, cdr(eax)
    mov eax, car(eax)
    jmp [ebp + cont.program]

app_div_and_mod:
  .A2:
    instrumentation_point
    call check_div_args
    jz .big
  .fixint:
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
  .big:
    push ecx
    push nil_tag
    call rn_cons
    push ebx
    push eax
    call rn_cons
    mov ebx, eax
    mov eax, private_binding(rom_string_general_div_and_mod)
    mov edi, private_binding(rom_string_private_environment)
    jmp rn_combine

;;
;; check_div_args (native procedure)
;;
;; preconditions:  EBX = dividend
;;                 ECX = divisor
;;                 ESI = symbol for error reporting
;;
;; postconditions: ZF = 0, if both arguments are fixints
;;                 ZF = 1, if both arguments are integers
;;                         and at least one is bigint
;;                         or fixint_min.
;;
check_div_args:
    call rn_numberP_procz
    jne .type_error
    mov dl, al
    xchg ebx, ecx
    call rn_numberP_procz
    jne .type_error
    xchg ebx, ecx
    cmp ecx, fixint_value(0)
    je .divz
    cmp ebx, fixint_value(min_fixint)
    je .force_bigint
    or al, dl
    cmp al, 1
    ja .inf
  .force_bigint:
    ret
  .inf:
    mov edx, err_invalid_argument
    jmp .error
  .divz:
    mov edx, err_division_by_zero
    jmp .error
  .type_error:
    mov edx, err_invalid_argument
  .error:
    push ebx
    push ecx
    call rn_cons
    mov ebx, eax
    mov eax, edx
    mov ecx, esi
    jmp rn_error

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
