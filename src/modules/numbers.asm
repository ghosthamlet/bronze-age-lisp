;;;
;;; number.asm
;;;
;;; Kernel number features - fixint only.
;;;
;;; todo - overflow checks

rn_fixintP_procz:
    mov eax, ebx
    xor al, 1
    test al, 3
    ret

check_fixint:
  .app_3:
    xchg ebx, edx
    call rn_fixintP_procz
    jne .type_error
    xchg ebx, edx
    ret
  .app_2:
    xchg ebx, ecx
    call rn_fixintP_procz
    jne .type_error
    xchg ebx, ecx
    ret
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
    call check_fixint.app_1
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call check_fixint.app_2
    lea eax, [ebx + ecx - 1]
    jmp [ebp + cont.program]
  .A3:
    call check_fixint.app_3
    lea eax, [ebx + ecx - 1]
    lea eax, [eax + edx - 1]
    jmp [ebp + cont.program]
  .operate:
    mov eax, err_not_implemented
    jmp rn_error

app_times:
  .A0:
    mov eax, fixint_value(1)
    jmp [ebp + cont.program]
  .A1:
    call check_fixint.app_1
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    call check_fixint.app_2
    sar ebx, 2
    sar ecx, 2
    imul ebx, ecx
    lea eax, [1 + 4*ebx]
    jmp [ebp + cont.program]
  .A3:
    call check_fixint.app_3
    sar ebx, 2
    sar ecx, 2
    sar edx, 2
    imul ebx, ecx
    imul ebx, edx
    lea eax, [1 + 4*ebx]
    jmp [ebp + cont.program]
  .operate:
    mov eax, err_not_implemented
    jmp rn_error

app_minus:
  .A2:
    call check_fixint.app_2
    sar ebx, 2
    sar ecx, 2
    sub ebx, ecx
    lea eax, [1 + 4*ebx]
    jmp [ebp + cont.program]
  .A3:
    call check_fixint.app_3
    sar ebx, 2
    sar ecx, 2
    sar edx, 2
    sub ebx, ecx
    sub ebx, edx
    lea eax, [1 + 4*ebx]
    jmp [ebp + cont.program]
  .operate:
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
;; helper for (<? ...)
;;
rel_fixint_le:
    call check_fixint.app_2
    xor eax, eax
    cmp ebx, ecx
    setl al
    ret

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
