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
    mov eax, err_invalid_argument_structure
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
;; preconditions:  EAX = ESI = closure
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
    and eax, 0x000000FF
    mov ah, al
    mov al, boolean_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, [esi + operative.var0]
    jmp rn_error
  .operate:
    mov edi, ebx
    call rn_list_metrics
    mov ebx, edi            ; for error messages
    test eax, eax
    jz .error
    test edx, edx
    jz .yes
    push edx
  .next:
    mov ebx, car(edi)
    mov edi, cdr(edi)
    call [esi + operative.var1]
    test al, al
    jz .done
    dec dword [esp]
    jnz .next
  .done:
    pop edx
  .yes:
    and eax, 0x000000FF
    mov ah, al
    mov al, boolean_tag
    jmp [ebp + cont.program]

;; unary type predicates (native procedures)
;;
;; preconditions:  EBX = object
;;                 ESI = operative closure
;;                 EBP = current continuation
;; postconditions: AL = 1 if object satisfies the predicate
;;                 AL = 0 otherwise
;; preserves:      ESI, EDI, EBP, ESP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;;
pred_char:
    cmp bl, char_tag
    jne .no
    mov eax, ebx
    shr eax, 8
    call [esi + operative.var2]
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

pred_combiner:
    cmp bl, primitive_tag
    je .yes
    test bl, 3
    jnz .no
    mov eax, [ebx]
    cmp al, operative_header(0)
    je .yes
    cmp al, applicative_header(0)
    jne .no
  .yes:
    mov eax, 1
    ret
  .no:
    xor eax, eax
    ret

pred_mutable_pair:
    mov eax, ebx
    xor eax, 0x80000003
    test eax, 0x80000003
    setz al
    ret

pred_immutable_pair:
    mov eax, ebx
    xor eax, 0x00000003
    test eax, 0x80000003
    setz al
    ret

pred_integer:
    call rn_integerP_procz
    setz al
    ret

pred_finite_number:
    call rn_numberP_procz
    jnz .nan
    cmp al, 2
    setne al
    ret
  .nan:
    mov eax, err_not_a_number
    mov ecx, [esi + operative.var0]
    jmp rn_error

pred_number:
    xor eax, eax
    call rn_numberP_procz
    setz al
    ret

pred_zero:
    call rn_numberP_procz
    jne .nan
    xor eax, eax
    cmp ebx, fixint_value(0)
    setz al
    ret
  .nan:
    mov eax, err_not_a_number
    mov ecx, [esi + operative.var0]
    jmp rn_error

pred_positive:
    call rn_siglog
    jne pred_zero.nan
    test eax, eax
    jz .no
    setns al
    ret
  .no:
    xor eax, eax
    ret

pred_negative:
    call rn_siglog
    jne pred_zero.nan
    test eax, eax
    sets al
    ret

pred_even:
    call rn_integerP_procz
    jnz .nan
    test al, al
    jz .fixint
    mov ebx, [ebx + bigint.digit0]
  .fixint:
    test ebx, 4
    setz al
    ret
  .nan:
    mov eax, err_not_a_number
    mov ecx, [esi + operative.var0]
    jmp rn_error

pred_odd:
    call rn_integerP_procz
    jnz pred_even.nan
    test al, al
    jz .fixint
    mov ebx, [ebx + bigint.digit0]
  .fixint:
    test ebx, 4
    setnz al
    ret

pred_u8:
    call rn_u8P_procz
    setz al
    ret

pred_finite_list:
    call rn_list_metrics
    test eax, eax
    jz .no
    test ecx, ecx
    jnz .no
    ret            ; here, EAX = 1, ECX = 0
  .no:
    xor eax, eax
    ret

pred_countable_list:
    jmp rn_list_metrics

pred_library_name_component:
    cmp bl, symbol_tag
    je .yes
    cmp bl, einf_tag
    je .no
    call rn_siglog
    jne .no
    test eax, eax
    setns al
    ret
  .no:
    xor eax, eax
    ret
  .yes:
    mov eax, 1
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
    push ebx
    call rn_list_metrics
    pop ebx
    test eax, eax
    jz .error
    test ecx, ecx
    jz .acyclic
    inc edx
  .acyclic:
    cmp edx, 2
    jb .A0
    lea ecx, [edx - 1]
    mov edx, cdr(ebx)
    mov ebx, car(ebx)
  .next:
    push ecx
    mov ecx, car(edx)
    mov edx, cdr(edx)
    call [esi + operative.var1]
    mov ebx, ecx
    pop ecx
    test eax, eax
    jz .no
    loop .next
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .no:
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, [esi + operative.var0]
    call rn_error

rel_char:
    cmp bl, char_tag
    jne .error
    xchg ebx, ecx
    cmp bl, char_tag
    jne .error
    xchg ebx, ecx
    mov eax, ebx
    sub eax, ecx
    test eax, eax
    jz .signum
    sar eax, 31
    lea eax, [2*eax + 1]
  .signum:
    add eax, 3
    push ebx
    mov ebx, [esi + operative.var2]
    bt ebx, eax
    setc al
    and eax, 0xFF
    pop ebx
    ret
  .error:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var0]
    call rn_error

rel_string:
    cmp bl, string_tag
    jne .error
    xchg ebx, ecx
    cmp bl, string_tag
    jne .error
    xchg ebx, ecx
    push ebx
    push ecx
    push edx
    call .compare
    lea eax, [eax + 3]
    mov ebx, [esi + operative.var2]
    bt ebx, eax
    setc al
    and eax, 0xFF
    pop edx
    pop ecx
    pop ebx
    ret
  .error:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var0]
    call rn_error
  .compare:
    push ebx
    push ecx
    call rn_get_blob_data
    mov eax, ecx
    mov ebx, [esp]
    call rn_get_blob_data
    mov edx, ecx
    pop ecx
    pop ebx
    cmp eax, edx
    jl .ebx_shorter
    jg .ecx_shorter
  .same_length:
    mov eax, ebx
    mov ebx, ecx
    call rn_compare_blob_bits
    jz .eq
    setc al
  .sgn:
    and eax, 0x000000FF
    lea eax, [2*eax - 1]
    ret
  .eq:
    xor eax, eax
    ret
  .ebx_shorter:
    push eax
    mov eax, ebx
    mov ebx, ecx
    call rn_compare_blob_bits
    setc al
    pop edx
    lea edx, [8*edx]
    cmp ecx, edx
    jb .sgn
  .lt:
    mov eax, -1
    ret
  .ecx_shorter:
    xchg ebx, ecx
    xchg eax, edx
    call .ebx_shorter
    neg eax
    ret

rel_integer:
    push ebx
    push ecx
    push edx
    push edi
    mov edi, [esi + operative.var0]
    call rn_integer_compare
    test eax, eax
    jz .signum
    sar eax, 31
    lea eax, [2*eax + 1]
  .signum:
    add eax, 3
    mov ebx, [esi + operative.var2]
    bt ebx, eax
    setc al
    and eax, 0xFF
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
