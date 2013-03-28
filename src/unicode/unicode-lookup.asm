;;;
;;; unicode-lookup.asm
;;;

;;
;; unicode_bsearch_16_16 (native procedure)
;;
;; preconditions:  EAX = code point
;;                 EBX = interval table base
;;                 ECX = interval table length
;;
;; postconditions: AL = 0 if not found
;;                    = 1 if found
;;
unicode_bsearch_16_16:
    push ebp
    push esi
    push edi
    mov esi, ebx
    mov ebx, 0
    dec ecx
    call .loop
    pop edi
    pop esi
    pop ebp
    ret
  .loop:
    mov edi, ebx
    add edi, ecx
    shr edi, 1
    movzx edx, word [esi + 4 * edi]
    cmp eax, edx
    jb .low
    mov ebp, edx
    movzx edx, word [esi + 4 * edi + 2]
    add edx, ebp
    cmp eax, edx
    ja .high
    mov al, 1
    ret
  .low:
    lea ecx, [edi - 1]
    cmp ebx, ecx
    jbe .loop
    xor al, al
    ret
  .high:
    lea ebx, [edi + 1]
    cmp ebx, ecx
    jbe .loop
    xor al, al
    ret
