;;;
;;; continuations.asm
;;;

app_apply_continuation:
  .A2:
    ;; ebx = continuation
    ;; ecx = argument
    ;; ebp = current continuation
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, cont_header(0)
    jne .error
    jmp rn_apply_continuation
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_apply_continuation)
    jmp rn_error

;;
;; primop_Slet_cc (continuation passing procedure)
;;
;; Implementation of ($let/cc SYMBOL . BODY)
;;
;; preconditions:  EBX = (SYMBOL . BODY)
;;                 EDI = dynamic environment
;;                 EBP = current continuation
primop_Slet_cc:
    call rn_pairP_procz
    jnz .error
    mov edx, car(ebx)
    cmp dl, symbol_tag
    jne .error
    ;; capture continuation
    mov eax, ebp
    call rn_capture
    ;; create environment
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + environment.header], dword environment_header(6)
    mov [eax + environment.program], dword tail_env_lookup
    mov [eax + environment.parent], edi
    mov [eax + environment.key0], edx
    mov [eax + environment.val0], ebp
    mov [eax + environment.key1], edx ; unused, padding only
    mov edi, eax
    mov ebx, cdr(ebx)
    jmp rn_sequence
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Slet_cc)
    jmp rn_error

;;
;; app_3_guard_continuation (continuation passing procedure)
;;
;; Implementation of (guard-continuation ENTRY TARGET EXIT).
;;
;; preconditions:  EBX = entry guard list
;;                 ECX = target continuation
;;                 EDX = exit guard list
;;
app_guard_continuation:
  .A3:
    mov esi, symbol_value(rom_string_guard_continuation)
    test cl, 3
    jnz .error
    mov eax, [ecx]
    cmp al, cont_header(0)
    jne .error
    push ebx
    ;; create outer continuation
    mov ebx, edx
    mov edx, ecx
    mov ecx, cont_outer
    call make_guard_continuation
    ;; create inner continuation
    pop ebx
    mov ecx, cont_inner
    mov edx, eax
    call make_guard_continuation
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ebx, ecx
    mov ecx, esi
    jmp rn_error

;;
;; app_guard_dynamic_extent (continuation passing procedure)
;;
;; Implementation of (guard-dynamic-extent ENTRY COMBINER EXIT).
;;
;; preconditions:  EBX = entry guard list
;;                 ECX = target combiner
;;                 EDX = exit guard list
;;
app_guard_dynamic_extent:
  .A3:
    mov esi, symbol_value(rom_string_guard_dynamic_extent)
    push ebx
    mov ebx, ecx
    call pred_combiner
    test eax, eax
    jz .not_a_combiner
    call rn_fully_unwrap
    mov ecx, eax
    pop ebx
    push ecx
    push edx
    ;; capture current continuation
    mov eax, ebp
    call rn_capture
    ;; create outer continuation
    mov ecx, cont_outer
    mov edx, ebp
    call make_guard_continuation
    ;; create inner continuation
    pop ebx
    mov ecx, cont_inner
    mov edx, eax
    call make_guard_continuation
    ;; change current continuation
    mov ebp, eax
    pop eax
    mov ebx, nil_tag
    jmp rn_combine
  .not_a_combiner:
    pop eax
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_guard_dynamic_extent)
    jmp rn_error

;;
;; make_guard_continuation (native procedure)
;;
;; Allocates a guard continuation (inner or outer).
;;
;; preconditions:  EBX = guard list
;;                 ECX = program pointer (cont_inner or cont_outer)
;;                 EDX = parent continuation
;;                 ESI = symbol for error reporting
;;                 EDI = dynamic environment for interceptors
;;
;; postconditions: EAX = new continuation object
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX
;;
make_guard_continuation:
    push ebx
    push ecx
    push edx
    ;; check guard list
    call rn_list_metrics
    test eax, eax
    jz .invalid_guard_list
    test ecx, ecx
    jnz .invalid_guard_list
    ;; allocate object of length (4 + 2*N) dwords
    lea ecx, [4 + 2*edx]
    call rn_allocate
    rn_trace configured_debug_continuations, 'make-guard', hex, eax, hex, ecx
    shl ecx, 8
    mov cl, cont_header(0)
    mov [eax + cont.header], ecx
    ;; fill code, parent and environment
    pop dword [eax + cont.parent]
    pop dword [eax + cont.program]
    mov [eax + cont.var0], edi
    mov ecx, edx
    jecxz .done
    push eax
    push esi
    mov edx, ebx
    lea esi, [eax + cont.var1]
  .next_clause:
    mov ebx, car(edx)
    mov edx, cdr(edx)
    ;; each clause must be a two-element list
    push ebx
    push ecx
    push edx
    call rn_list_metrics
    test eax, eax
    jz .invalid_clause
    test ecx, ecx
    jnz .invalid_clause
    cmp edx, 2
    jne .invalid_clause
    pop edx
    pop ecx
    pop ebx
    ;; the first element must be a continuation
    mov eax, car(ebx)
    test al, 3
    jnz .invalid_selector
    cmp byte [eax], cont_header(0)
    jne .invalid_selector
    mov [esi], eax
    ;; the second element must be an combiner
    mov ebx, cdr(ebx)
    mov ebx, car(ebx)
    call pred_combiner
    test eax, eax
    jz .invalid_interceptor
    push ecx
    call rn_fully_unwrap
    pop ecx
    mov [esi + 4], eax
    call .dbg
    ;; move to the next element
    lea esi, [esi + 8]
    loop .next_clause
    pop esi
    pop eax
  .done:
    pop ebx
    ret
  .dbg:
    rn_trace configured_debug_continuations, 'make-guard-2', hex, [esi], hex, [esi + 4]
    ret
  .invalid_guard_list:
    pop edx
    pop ecx
    pop ebx
    mov eax, err_invalid_guard_list
    mov ecx, esi
    jmp rn_error
  .invalid_clause:
    pop edx
    pop ecx
    pop ebx
    pop esi
    pop eax
    pop eax
    mov eax, err_invalid_guard_clause
    mov ecx, esi
    jmp rn_error
  .invalid_selector:
    mov ebx, eax
    pop esi
    pop eax
    pop eax
    mov eax, err_invalid_selector
    mov ecx, esi
    jmp rn_error
  .invalid_interceptor:
    pop esi
    pop eax
    pop eax
    mov eax, err_invalid_interceptor
    mov ecx, esi
    jmp rn_error


;;
;; app_exit (continuation passing procedure)
;;
;; Implementation of (exit [OBJECT])
;;
app_exit:
  .A0:
    mov ebx, inert_tag
  .A1:
    mov ecx, ebx
    mov ebx, root_continuation
    jmp rn_apply_continuation

;;
;; app_extend_continuation (continuation passing procedure)
;;
;; Implementation of (extend-continuation CONT APPV [ENV])
;;
app_extend_continuation:
  .A2:
    push ebx
    mov ebx, empty_env_object
    call rn_make_list_environment
    mov edx, eax
    pop ebx
  .A3:
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, cont_header(0)
    jne .error
    mov esi, ebx                    ; ESI := CONT
    mov ebx, edx                    ; EBX := ENV
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .error
    mov ebx, ecx                    ; EBX := APPV
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .error
    call rn_fully_unwrap            ; EBX := underlying operative
    mov ecx, 6
    call rn_allocate
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .do
    mov [eax + cont.parent], esi
    mov [eax + cont.var0], ebx
    mov [eax + cont.var1], edx
    mov [eax + cont.var2], dword inert_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_extend_continuation)
    jmp rn_error
  .do:
    mov ebx, eax
    mov eax, [ebp + cont.var0]
    mov edi, [ebp + cont.var1]
    mov ebp, [ebp + cont.parent]
    jmp rn_combine

;;
;; app_continuation_applicative (continuation passing procedure)
;;
;; Implementation of (continuation-applicative CONT)
;;
app_continuation_Gapplicative:
  .A1:
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, cont_header(0)
    jne .error
    call rn_continuation_applicative
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_continuation_Gapplicative)
    jmp rn_error
