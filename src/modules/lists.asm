;;;
;;; lists.asm
;;;
;;; High-level list manipulation procedures.
;;;

;;
;; app_assoc (continuation passing procedure)
;;
;; Implementation of (assoc KEY ALIST) and (assq KEY ALIST).
;;
;; preconditions: EBX = 1st arg = KEY
;;                ECX = 2nd arg = ALIST
;;                EBP = continuation
;;
;; closure: [ESI + operative.var0] = app_assoc
;;          [ESI + operative.var1] = symbol |assoc| or |assq|
;;          [ESI + operative.var2] = address of rn_equal or rn_eq
;;
app_assoc:
    push ebx
    push ecx
    mov ebx, ecx
    call rn_list_metrics
    test eax, eax
    jz .invalid_list
    mov ecx, edx
    pop edi
    pop edx
    jecxz .not_found
  .next_element:
    mov ebx, car(edi)
    call rn_pairP_procz
    jne .invalid_element
    mov ebx, car(ebx)
    push ecx
    mov ecx, edx
    call [esi + operative.var2]
    pop ecx
    test eax, eax
    jnz .found
    mov edi, cdr(edi)
    loop .next_element
  .not_found:
    mov eax, nil_tag
    jmp [ebp + cont.program]
  .found:
    mov eax, car(edi)
    jmp [ebp + cont.program]
  .invalid_list:
    pop ebx
    pop eax
  .invalid_element:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var1]
    jmp rn_error

;;
;; app_member (continuation passing procedure)
;;
;; Implementation of (member? KEY LIST) and (memq? KEY LIST).
;;
;; preconditions: EBX = 1st arg = KEY
;;                ECX = 2nd arg = LIST
;;                EBP = continuation
;;
;; closure: [ESI + operative.var0] = app_assoc
;;          [ESI + operative.var1] = symbol |member?| or |memq?|
;;          [ESI + operative.var2] = address of rn_equal or rn_eq
;;
app_member:
    push ebx
    push ecx
    mov ebx, ecx
    call rn_list_metrics
    test eax, eax
    jz .invalid_list
    pop edi
    pop ebx
    test edx, edx
    jz .not_found
    dec edx
    mov ecx, car(edi)
    call [esi + operative.var2]
    test eax, eax
    jnz .found
    test edx, edx
    jz .not_found
  .next:
    mov edi, cdr(edi)
    mov ecx, car(edi)
    call [esi + operative.var2]
    test eax, eax
    jne .found
    dec edx
    jnz .next
  .not_found:
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
  .found:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .invalid_list:
    pop ebx
    pop eax
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var1]
    jmp rn_error
