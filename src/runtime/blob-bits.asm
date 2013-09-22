;;;
;;; blob-bits.asm
;;;
;;; Blobs as bit strings.
;;;

;;
;; rn_blob_bit (native procedure)
;;
;; Returns bit value at the given index in a blob. A blob
;; consisting of bytes X[0], X[1], ..., X[N] is identified
;; with the bit string B[0], B[1], B[2], ..., where
;;
;;  B[j] = !! (X[j / 8] & (0x80 >> (j % 8))), if j < 8*N
;;  B[j] = 0,                                 if j = 8*N
;;  B[j] = 1,                                 if j > 8*N
;;
;; preconditions:  EAX = bit index (0..2^32-1)
;;                 EBX = blob
;;
;; postconditions: EAX = bit value 0 or 1
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX
;; stack usage:    3 (incl. call/ret)
;;
rn_blob_bit:
    push ebx
    push ecx
    call rn_get_blob_data
    lea ecx, [8*ecx]
    cmp eax, ecx
    seta cl
    jae .done
    mov cx, ax
    shr eax, 3
    and cx, 7
    neg cx
    add cx, 7
    movzx ax, byte [ebx + eax]
    bt ax, cx
    setc cl
  .done:
    movzx eax, cl
    pop ecx
    pop ebx
    ret

;;
;; rn_compare_blob_bits (native procedure)
;;
;; Compares two blobs and computes index of first bit
;; in the difference.
;;
;; preconditions:  EAX = blob A (string/bytevector/symbol/keyword)
;;                 EBX = blob B (string/bytevector/symbol/keyword)
;; postconditions if A and B are equal:
;;                 ZF = 1
;;                 ECX = 0xFFFFFFFF
;; postconditions if A and B are not equal:
;;                 ZF = 0
;;                 CF = value of critical bit in A
;;                 ECX = index of first bit in the difference

rn_compare_blob_bits:
    push eax
    push ebx
    push edx
    push esi
    push edi
    m_get_blob_data eax, esi, ecx
    m_get_blob_data ebx, edi, edx
    push dword 1
    cmp ecx, edx
    jbe .L1
    xchg ecx, edx
    xchg esi, edi
    mov [esp], dword 0
  .L1:
    push edi
    jecxz .prefix
    sub edx, ecx
    repe cmpsb
    jz .prefix
  .compare:
    mov cl, byte [esi - 1]
    mov dl, byte [edi - 1]
  .compare_cl_dl:
    xor cl, dl
    bsr ax, cx
    bt  dx, ax
    setc dl
    neg al
    add al, 7
  .add_byte_index:
    pop esi
    sub edi, esi
    lea ecx, [8*(edi - 1)]
    or cl, al
    movzx eax, dl
    pop edx
    xor edx, eax
    cmp dl, 2         ; clear ZF
    bt dx, 0          ; set or clear CF according to the result
  .done:
    pop edi
    pop esi
    pop edx
    pop ebx
    pop eax
    ret
  .prefix:
    test edx, edx
    jz .equal
    mov cl, 0x7F
    mov dl, byte [edi]
    inc edi
    cmp cl, dl
    jnz .compare_cl_dl
    mov ecx, edx
    mov al, 0xFF
    repe scasb
    jnz .tail
    mov al, 0
    jmp .add_byte_index
  .equal:
    add esp, 8
    mov ecx, 0xFFFFFFFF
    xor eax, eax      ; set ZF = 1
    jmp .done
  .tail:
    mov cl, al
    mov dl, byte [edi - 1]
    jmp .compare_cl_dl
