;;;
;;; list-metrics.asm
;;;
;;; Compute length of lists, cyclic lists and improper lists.
;;;

cycle_detection_parameter equ 7

;;
;; rn_list_metrics (native procedure)
;;
;; preconditions:  EBX = any lisp object
;;
;; postconditions: EAX = 1 for proper list
;;                     = 0 for improper list
;;                 EBX = input object if acyclic list
;;                     = cycle start element if cyclic list
;;                 ECX = cycle length if cyclic
;;                     = 0 if acyclic
;;                 EDX = pair count
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX
;; stack usage:    3 dwords (incl. call/et)
;;
rn_list_metrics:
    cmp bl, nil_tag
    je .empty_list
    test bl, 3
    jz .no_list
    jnp .no_list
    ;; brent algorithm
    mov edx, cycle_detection_parameter
    push esi
    push ebx
  .L1:
    mov esi, ebx
    mov ecx, edx
  .L2:
    mov ebx, cdr(ebx)
    cmp ebx, esi
    je .cyclic
    test bl, 3
    jz .acyclic
    jnp .acyclic
    loop .L2
    shl edx, 1
    jmp .L1
  .acyclic:
    add edx, edx
    sub edx, ecx
    sub edx, cycle_detection_parameter - 1
    xor ecx, ecx
    xor eax, eax
    cmp bl, nil_tag
    sete al
    pop ebx
    pop esi
    ret
  .cyclic:
    sub edx, ecx
    inc edx
    mov ecx, edx
    pop ebx
    mov esi, ebx
  .L3:
    mov esi, cdr(esi)
    loop .L3
    mov ecx, edx
    cmp ebx, esi
    jz .end
  .L4:
    inc edx
    mov ebx, cdr(ebx)
    mov esi, cdr(esi)
    cmp ebx, esi
    jne .L4
  .end:
    xor eax, eax
    mov al, 1
    pop esi
    ret
  .empty_list:
    xor eax, eax
    inc al
    xor ecx, ecx
    xor edx, edx
    ret
  .no_list:
    xor eax, eax
    xor ecx, ecx
    xor edx, edx
    ret

;;
;; rn_pairP_procz (native procedure)
;;
;; Determines whether an object is a pair or not.
;;
;; preconditions:  EBX = value
;;                 native stack suitable for RET instruction
;; postconditions: ZF = 1 if value is a pair
;;                 ZF = 0 otherwise
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP (call/ret)
;; clobbers:       EFLAGS
;;
;; example: mov ebx, VALUE
;;          call rn_pairP_procz
;;          jz IS_PAIR
;;          jmp IS_NOT_PAIR
;;
rn_pairP_procz:
    test bl, 3
    jz .no
    jp .yes
  .no:
    cmp bl, 3   ; ZF := 0
    ret
  .yes:
    cmp bl, bl  ; ZF := 1
    ret
