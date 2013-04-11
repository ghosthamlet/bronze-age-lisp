;;;
;;; keyed-variables.asm
;;;
;;; Static and dynamic keyed variables.
;;;

;; app_make_keyed_dynamic_variable (continuation passing procedure)
;;
;; Implementation of (make-keyed-dynamic-variable).
;;
;; Value of the dynamic variable is stored in the closure
;; of the operative underlying the corresponding accessor
;; in the slot operative.var1. If the variable is not bound,
;; the slot contains "unbound_tag".
;;
app_make_keyed_dynamic_variable:
  .A0:
    ;; allocate memory for accessor and binder
    mov ecx, 16
    call rn_allocate
    ;; initialize operative underlying the accessor
    mov [eax + operative.header], dword operative_header(4)
    mov [eax + operative.program], dword rn_asm_operative.L00
    mov [eax + operative.var0], dword app_access_dynamic_variable.A0
    mov [eax + operative.var1], dword unbound_tag
    mov edx, eax
    ;; initialize accessor applicative
    lea eax, [eax + 16]
    mov [eax + applicative.header], dword applicative_header(4)
    mov [eax + applicative.program], dword rn_asm_applicative.L00
    mov [eax + applicative.underlying], edx
    mov [eax + applicative.var0], dword app_access_dynamic_variable.A0
    mov edi, eax
    ;; initialize operative underlying the binder
    lea eax, [eax + 16]
    mov [eax + operative.header], dword operative_header(4)
    mov [eax + operative.program], dword rn_asm_operative.L22
    mov [eax + operative.var0], dword app_bind_dynamic_variable.A2
    mov [eax + operative.var1], edx
    mov edx, eax
    ;; initialize binder applicative
    lea eax, [eax + 16]
    mov [eax + applicative.header], dword applicative_header(4)
    mov [eax + applicative.program], dword rn_asm_applicative.L22
    mov [eax + applicative.underlying], edx
    mov [eax + applicative.var0], dword app_bind_dynamic_variable.A2
    mov esi, eax
    ;; return the list (binder accessor)
    push edi
    push dword nil_tag
    call rn_cons
    push esi
    push eax
    call rn_cons
    jmp [ebp + cont.program]

app_access_dynamic_variable:
  .A0:
     mov eax, [esi + operative.var1]
     cmp eax, unbound_tag
     je .unbound
     jmp [ebp + cont.program]
  .unbound:
     mov eax, err_unbound_dynamic_variable
     mov ebx, inert_tag
     mov ecx, inert_tag
     jmp rn_error

app_bind_dynamic_variable:
  .A2:
    cmp cl, primitive_tag
    je .ok
    test cl, 3
    jnz .error
    mov eax, [ecx]
    cmp al, applicative_header(0)
    je .ok
    cmp al, operative_header(0)
    je .ok
  .error:
    mov eax, err_invalid_argument
    mov ebx, ecx
    mov ecx, inert_tag
    jmp rn_error
  .ok:
    mov edi, [esi + operative.var1] ; EDI := accessor object
    mov eax, ebp
    call rn_capture       ; capture current continuation
    mov edx, ecx          ; EDX := combiner
    mov ecx, 26           ; allocate memory for two combiners
    call rn_allocate      ;   and three continuations
    ;; exit interceptor
    mov [eax + operative.header], dword operative_header(4)
    mov [eax + operative.program], dword .intercept
    mov [eax + operative.var0], edi
    mov ecx, [edi + operative.var1]  ; get currently bound value
    mov [eax + operative.var1], ecx  ; old value in exit interceptor
    push eax
    lea eax, [eax + 16]
    ;; entry interceptor
    mov [eax + operative.header], dword operative_header(4)
    mov [eax + operative.program], dword .intercept
    mov [eax + operative.var0], edi
    mov [eax + operative.var1], ebx  ; new value in entry interceptor
    mov ecx, eax
    lea eax, [eax + 16]
    ;; outer guard continuation
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword cont_outer
    mov [eax + cont.parent], ebp
    mov [eax + cont.guard.environment], dword empty_env_object
    mov [eax + cont.guard.selector0], dword root_continuation
    mov [eax + cont.guard.selector0 + 4], ecx
    mov ecx, eax
    lea eax, [eax + 24]
    ;; inner guard continuation
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword cont_inner
    mov [eax + cont.parent], ecx
    mov [eax + cont.guard.environment], dword empty_env_object
    mov [eax + cont.guard.selector0], dword root_continuation
    pop dword [eax + cont.guard.selector0 + 4]
    mov ecx, eax
    lea eax, [eax + 24]
    ;; continuation for normal exit handling
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.parent], ecx
    mov [eax + cont.program], dword .undo
    mov ebp, eax                           ; make it current cont.
    mov eax, [edi + operative.var1]        ; currently bound value
    mov [ebp + cont.var0], edi             ; save acessor
    mov [ebp + cont.var1], eax             ; save current value
    mov [ebp + cont.var2], dword inert_tag
    mov [edi + operative.var1], ebx        ; set new value
    mov ebx, empty_env_object              ; create new initially
    call rn_make_list_environment          ;  empty environment
    mov edi, eax                           ; make it the dynamic env.
    mov eax, edx                           ; EAX := combiner
    mov ebx, nil_tag                       ; EBX := nil parameter tree
    jmp rn_combine                         ; invoke the combiner
  .undo:
    mov edi, [ebp + cont.var0]             ; accessor object
    mov ebx, [ebp + cont.var1]             ; copy previously bound
    mov [edi + operative.var1], ebx        ;  value back
    mov ebp, [ebp + cont.parent]
    xor ebx, ebx                           ; paranoia
    xor ecx, ecx
    xor edx, edx
    xor edi, edi
    xor esi, esi
    jmp [ebp + cont.program]
  .intercept:
    mov edi, [esi + operative.var0]   ; get accessor object
    mov ecx, [esi + operative.var1]   ; put new value of the dynamic variable
    mov [edi + operative.var1], ecx   ;   in the accessor object
    mov eax, car(ebx)                 ; pass forth the value which is
    jmp [ebp + cont.program]          ;   is being abnormally pased
