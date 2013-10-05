;;;
;;; native-interfaces.asm
;;;
;;; Support for runtime machine code generators.
;;;

;;
;; app_fixed_binding_address (continuation passing procedure)
;;
;; Implementation of (fixed-binding-address SYM).
;;
;; Return fixed virtual address in the private environment object
;; where is the binding of SYM stored. Signal an error if no such
;; fixed address exist.
;;
app_fixed_binding_address:
  .A1:
    cmp bl, symbol_tag
    jne .error
    cmp ebx, (256 * (1 + private_lookup_table_length))
    ja .error
    shr ebx, 8
    lea eax, [ground_private_lookup_table + 4 * (ebx - 1)]
    lea eax, [4 * eax + 1]
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_fixed_binding_address)
    jmp rn_error

;;
;; app_vector_GoperativeB (continuation passing procedure)
;;
;; Implementation of (vector->operative! VECTOR).
;;
;; VECTOR is changed into an operative combiner in-place. The vector
;; must have the form
;;
;;   #( #ignore FRAGMENT ENTRY NTEMP ... )
;;
;; where FRAGMENT is a bytevector containing position independent
;; native code. ENTRY is an integer specifying offset of the
;; entry point in the bytevector. NTEMP is either #inert or an fixint.
;;
;; If NTEMP is an integer, a continuation object storing temporary
;; variables is created each time the operative is invoked. The
;; continuation has the form
;;
;;  [ HDR ; .contstub ; PARENT ; OPERATIVE ; OFFSET ; <NTEMP slots> ]
;;
;; where PARENT is the continuation where the operative is invoked,
;; OPERATIVE is the operative closure, and OFFSET is initially set
;; to ENTRY. The code fragment may safely mutate this continuation.
;;
;; To observe alignment, NTEMP must be odd.
;;
;; preconditions:  EBX = VECTOR of length at least 4
;;
;;                 [EBX + 4] = #ignore (will be replaced by stub address)
;;                 [EBX + 8] = position-independent native code fragment (bytevector)
;;                 [EBX + 12] = offset of the entry point in the fragment (tagged fixint)
;;                 [EBX + 16] = size of auxilliary continuation closure (tagged fixint)
;;                 EBP = current continuation
;;
app_vector_GoperativeB:
  .A1:
    test ebx, 3
    jnz .invalid_argument
    mov eax, [ebx]
    cmp al, vector_header(0)
    jne .invalid_argument
    mov eax, ebx
    shr eax, 8                         ; EAX := vector object size
    cmp eax, 6
    jb .invalid_argument
    mov eax, [ebx + vector.element0]
    cmp eax, ignore_tag
    jne .invalid_argument
    mov eax, [ebx + vector.element1]
    cmp al, bytevector_tag
    jne .invalid_argument
    mov eax, [ebx + vector.element2]
    xor al, 1
    test al, 3
    jnz .invalid_argument
    mov eax, [ebx + vector.element3]
    cmp al, inert_tag
    je .checked
    xor al, 5
    test al, 7
    jnz .invalid_argument
  .checked:
    mov byte [ebx + vector.header], operative_header(0)
    mov [ebx + operative.program], dword .stub
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_vector_GoperativeB)
    jmp rn_error
    align 4
  .stub:
    mov esp, [stack_limit]           ; clear the native stack
    mov eax, [esi + operative.var2]  ; get aux continuation size
    cmp al, inert_tag
    mov edx, [esi + operative.var1]  ; get offset from closure
    je .jump_to_bytevector
    shr eax, 2                       ; untag
    lea ecx, [eax + 5]               ; add 5 for the header
    neg ecx
    call rn_allocate_transient
    neg ecx
    shl ecx, 8
    mov cl, cont_header(0)
    mov [eax + cont.header], ecx
    mov [eax + cont.program], dword .contstub
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], esi
    mov [eax + cont.var1], edx
    mov ebp, eax
    push edi
    lea edi, [eax + cont.var2]
    shr ecx, 8
    lea ecx, [ecx - 5]
    mov eax, inert_tag
    rep stosd
    pop edi
    jmp .jump_to_bytevector
  .contstub:
    call rn_force_transient_continuation
    mov esi, [ebp + cont.var0]
    mov edx, [ebp + cont.var1]
  .jump_to_bytevector:
    mov ecx, [esi + operative.var0]  ; get bytevector from closure
    shr ecx, 8                       ; untag
    mov ecx, blob_address(ecx)       ; bytevector data address
    shr edx, 2                       ; untag
    add ecx, edx
    jmp ecx                          ; jump into bytevector data

;;
;; app_operative_Gvector (continuation passing procedure)
;;
;; Implementation of (operative->vector OP).
;;
;; If the underlying combiner of OP is an operative created by
;; (vector->operative! V1) for some vector V1, return a newly
;; allocated vector V2 which is equal to the original vector V1.
;;
app_operative_Gvector:
  .A1:
    call rn_fully_unwrap
    test ebx, 3
    jnz .error
    mov eax, [ebx]
    cmp al, operative_header(0)
    jne .error
    cmp [ebx + operative.program], dword app_vector_GoperativeB.stub
    jne .error
    call rn_shallow_copy
    mov [eax + operative.program], dword ignore_tag
    mov byte [eax + vector.header], vector_header(0)
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_operative_Gvector)
    jmp rn_error
