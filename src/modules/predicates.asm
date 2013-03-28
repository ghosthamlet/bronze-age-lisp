;;;
;;; predicates.k
;;;
;;; Implementation of kernel predicates.
;;;

;;
;; op_immediate_type_predicate:
;;
;; Implementation of simple type predicate.
;;
;; preconditions:  EAX = closure
;;                 [EAX + operative.var0] = mask
;;                 [EAX + operative.var1] = tag
;;                 EBP = current continuation
;;
;;  for .A1:       EBX = argument
;;  for .operate:  EBX = argument list
;;
op_immediate_type_predicate:
  .A0:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .A1:
    mov edx, [eax + operative.var0]
    shr edx, 2
    mov esi, [eax + operative.var1]
    shr esi, 2
    and ebx, edx
    xor ebx, esi
    jmp .done
  .operate:
    mov esi, eax
    push ebx
    call rn_list_metrics
    pop ebx
    test eax, eax
    jz .error
    mov ecx, edx
    mov eax, esi
    mov edx, [eax + operative.var0]
    shr edx, 2
    mov esi, [eax + operative.var1]
    shr esi, 2
  .next:
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    and eax, edx
    xor eax, esi
    loope .next
  .done:
    mov eax, boolean_tag
    setz ah
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error

;;
;; op_header_type_predicate:
;;
;; Type predicate for heap-allocated values with headers.
;;
;; preconditions:  EAX = closure
;;                 [EAX + operative.var0] = mask
;;                 [EAX + operative.var1] = tag
;;                 EBP = current continuation
;;
;;  for .A1:       EBX = argument
;;  for .operate:  EBX = argument list
;;
op_header_type_predicate:
  .A0:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .A1:
    test bl, 3
    jnz .no
    mov ecx, [ebx]
    mov edx, [eax + operative.var0]
    shr edx, 2
    mov esi, [eax + operative.var1]
    shr esi, 2
    and ecx, edx
    xor ecx, esi
    jmp .done
  .no:
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
  .operate:
    mov esi, eax
    push ebx
    call rn_list_metrics
    pop ebx
    test eax, eax
    jz .error
    mov ecx, edx
    mov eax, esi
    mov edx, [eax + operative.var0]
    shr edx, 2
    mov esi, [eax + operative.var1]
    shr esi, 2
  .next:
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    test al, 3
    jnz .no
    mov eax, [eax]
    and eax, edx
    xor eax, esi
    loope .next
  .done:
    mov eax, boolean_tag
    setz ah
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error

;;
;; op_native_type_predicate:
;;
;; Implementation of type predicate based on native procedure.
;;
;; preconditions:  EAX = closure
;;                 [EAX + operative.var0] = name
;;                 [EAX + operative.var1] = native procedure
;;                 EBP = current continuation
;;
;;  for .A1:       EBX = argument
;;  for .operate:  EBX = argument list
;;
op_native_type_predicate:
  .A0:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .A1:
    mov eax, ebx
    call [esi + operative.var1]
    mov ah, al
    mov al, boolean_tag
    jmp [ebp + cont.program]
  .operate:
    mov eax, err_not_implemented
    mov ecx, [esi + operative.var0]
    call rn_error

pred_char:
    cmp bl, char_tag
    jne .no
    mov eax, ebx
    shr eax, 8
    call [esi + operative.var2]
    and eax, 0x000000FF
    ret
  .no:
    xor eax, eax
    ret

pred_operative:
    cmp bl, primitive_tag
    je .yes
    test bl, 3
    jnz .no
    mov eax, [ebx]
    cmp al, operative_header(0)
    jnz .no
  .yes:
    mov eax, 1
    ret
  .no:
    xor eax, eax
    ret

;;
;; op_relational_predicate:
;;
;; Implementation of relational predicate.
;;
;; preconditions:   ESI = closure
;;                  [ESI + operative.var0] = applicative's name
;;                  [ESI + operative.var1] = native binary predicate
;;                  EBP = current continuation
;;
;; for .A2 and .A3: EBX = argument1, ECX = argument2
;; for .A3:         EDX = argument3
;; for .operate:    EBX = argument list
;;
op_relational_predicate:
  .A0:
  .A1:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .A2:
    call [esi + operative.var1]
    mov ah, al
    mov al, boolean_tag
    jmp [ebp + cont.program]
  .A3:
    call [esi + operative.var1]
    mov ebx, ecx
    mov ecx, edx
    mov edx, eax
    call [esi + operative.var1]
    and eax, edx
    mov ah, al
    mov al, boolean_tag
    jmp [ebp + cont.program]
  .operate:
    mov eax, err_not_implemented
    mov ecx, [esi + operative.var0]
    call rn_error

rel_char_leq:
    cmp bl, char_tag
    jne .error
    cmp cl, char_tag
    jne .error
    xor eax, eax
    cmp ebx, ecx
    setbe al
    ret
  .error:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var0]
    call rn_error
