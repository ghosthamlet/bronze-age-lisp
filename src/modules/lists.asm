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

;;
;; app_append (continuation passing procedure)
;;
;; Implementation of applicative calls (append),
;; (append X) and (append X Y). General argument
;; lists are handled in lisp code.
;;
app_append:
  .A0:
    mov eax, nil_tag
    jmp [ebp + cont.program]
  .A1:
    mov eax, ebx
    jmp [ebp + cont.program]
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_append)
    jmp rn_error
  .A2_0:
    mov eax, edi
    jmp [ebp + cont.program]
  .A2_1:
    push dword car(esi)
    push edi
    call rn_cons
    jmp [ebp + cont.program]
  .A2:
    mov esi, ebx
    mov edi, ecx
    call rn_list_metrics
    mov ebx, esi
    test eax, eax
    jz .invalid_argument
    test ecx, ecx
    jnz .invalid_argument
    cmp edx, 1
    jb .A2_0
    je .A2_1
    lea ecx, [2 * edx]
    call rn_allocate
    push eax
    dec edx
  .next:
    mov ebx, car(esi)
    lea ecx, [eax + 8]
    shr ecx, 1
    or  ecx, 0x80000003
    mov [eax], ebx
    mov [eax + 4], ecx
    lea eax, [eax + 8]
    mov esi, cdr(esi)
    dec edx
    jnz .next
    mov ebx, car(esi)
    mov [eax], ebx
    mov [eax + 4], edi
    pop eax
    shr eax, 1
    or  eax, 0x80000003
    jmp [ebp + cont.program]
  .operate:
    mov eax, private_binding(rom_string_general_append)
    mov eax, [eax + applicative.underlying]
    jmp rn_combine

;;
;; app_reverse (continuation passing procedure)
;;
;; preconditions:  EBX = list to reverse
;;                 EBP = current continuation
;;
app_reverse:
  .A1:
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .error
    test ecx, ecx
    jnz .error
    mov eax, esi
    mov ebx, nil_tag
    lea edx, [4*edx + 1]
    call rn_list_rev
    mov eax, ebx
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ebx, esi
    mov ecx, symbol_value(rom_string_reverse)
    jmp rn_error
