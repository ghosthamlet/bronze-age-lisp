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
