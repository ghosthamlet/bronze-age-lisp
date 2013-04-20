;;;
;;; bitwise-operations.asm
;;;
;;; Bitwise operation on bigints and fixints
;;; a la SRFI-60.
;;;

;;
;; app_integer_length (continuation passing procedure)
;;
;; Implementation of (integer-length X), where X is integer.
;; Returns the least N such that X is representable as (N+1)-bit
;; signed integer (assuming twos-complement representation).
;;
;; compatibility: SRFI-60
;;
app_integer_length:
  .A1:
    call rn_integerP_procz
    jnz .error
    test al, al
    jz .fixint
    jmp .bigint
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_integer_length)
    jmp rn_error
  .fixint:
    xor esi, esi
    mov eax, ebx
    sar eax, 31
    xor eax, ebx
  .tag:
    or  eax, 3
    bsr eax, eax
    add eax, esi
    lea eax, [4*(eax - 1) + 1]
    jmp [ebp + cont.program]
  .bigint:
    mov ecx, [ebx + bigint.header]
    shr ecx, 8
    lea ecx, [ecx - 4]
    mov eax, 30
    mul ecx
    mov esi, eax
    mov eax, [ebx + 4*ecx + 12]
    mov edx, eax
    sar edx, 31
    xor eax, edx
    test eax, ~3
    jz .n2
    add esi, 60
    jmp .tag
  .n2:
    mov eax, [ebx + 4*ecx + 8]
    xor eax, edx
    test eax, ~3
    jz .n3
    add esi, 30
    jmp .tag
  .n3:
    mov eax, [ebx + 4*ecx + 4]
    xor eax, edx
    jmp .tag

;;
;; app_arithmetic_shift (continuation passing procedure)
;;
;; Implementation of (arithmetic-shift X H), where X is a number
;; and H is integer. The result Y is equal to X shifted by H bits
;; to the left (or -H bits to the right, if H < 0). Equivalently
;;
;;  Y = floor(X * 2^H)
;;
;; Special values
;;
;;    0 < |X| <= ∞, H = +∞ ==> Y = (sign of X) * ∞
;;    |X| < ∞, H = -∞ ==> Y = 0
;;
;; Undefined values
;;
;;    |X| = ∞, H = -∞
;;    X = 0, H = +∞
;;
;; compatibility: SRFI-60 (for finite inputs)
;;
app_arithmetic_shift:
  .A2:
    xor edx, edx
    call rn_numberP_procz
    jnz .type_error
    mov dl, al
    xchg ebx, ecx
    call rn_numberP_procz
    jnz .type_error
    shl dl, 2
    or dl, al
    xchg ebx, ecx
    call [.jump_table + 4*edx]
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_a_number
    mov ecx, symbol_value(rom_string_arithmetic_shift)
    jmp rn_error
  .undefined:
    mov eax, err_undefined_arithmetic_operation
    mov ecx, symbol_value(rom_string_arithmetic_shift)
    jmp rn_error

  .fix_fix:
    sar ecx, 2
    test ecx, ecx
    jz .any_zero
    jns .fix_fix_promote
    neg ecx
    cmp ecx, 30
    jae .zero_result
    mov eax, ebx
    shr eax, cl
    and al, ~3
    or al, 1
    ret
  .fix_fix_promote:
    mov edx, ebx
    bigint_extension edx
    push edx
    push edx
    push ebx
    push dword bigint_header(4)
    mov ebx, esp
    call rn_bigint_shift_left
    add esp, 16
    ret

  .zero_result:
    mov eax, fixint_value(0)
    ret

  .inf_inf:
    test ecx, ecx
    js .undefined
  .inf_fin:
  .any_zero:
    mov eax, ebx
    ret

  .big_fix:
    sar ecx, 2
    test ecx, ecx
    jz .any_zero
    js .big_fix_neg
    jmp rn_bigint_shift_left
  .big_fix_neg:
    neg ecx
    jmp rn_bigint_shift_right

  .fix_big:
  .big_big:
    mov edx, [ecx]
    shr edx, 8
    mov eax, [ecx + 4*edx - 4]
    test eax, eax
    js .zero_result
    mov eax, err_numeric_overflow
    mov ebx, ecx
    mov ecx, symbol_value(rom_string_arithmetic_shift)
    jmp rn_error

  .fin_inf:
    test ecx, ecx
    js .zero_result
    call rn_siglog
    sar eax, 31
    or ah, 1
    mov al, einf_tag
    ret

    align 16
  .jump_table:
    dd .fix_fix, .fix_big, .fin_inf, 0xDEAD0C10
    dd .big_fix, .big_big, .fin_inf, 0xDEAD0C20
    dd .inf_fin, .inf_fin, .inf_inf, 0xDEAD0C30
