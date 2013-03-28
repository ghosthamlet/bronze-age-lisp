;;;
;;; environment-mutations.asm
;;;

;;
;; rn_make_list_environment (native procedure)
;;
;; Allocate new, persistent list environment.
;;
;; preconditions:  EBX = parent environment
;; postconditions: EAX = new environment
;; preserves:      ECX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX
;; stack usage:    2 (incl. call/ret)
;;
rn_make_list_environment:
    push ecx
    mov ecx, 6
    call rn_allocate
    mov [eax + environment.header], dword environment_header(6)
    mov [eax + environment.program], dword tail_env_lookup
    mov [eax + environment.parent], ebx
    mov ecx, inert_tag
    mov [eax + environment.key0], ecx
    mov [eax + environment.val0], ecx
    mov [eax + environment.key1], ecx   ; unused, padding only
    pop ecx
    ret

;; rn_mutate_environment
;; rn_mutate_list_environment
;; rn_mutate_private_environment
;;
;; preconditions:  EAX = symbol
;;                 EBX = new value
;;                 EDI = environment
;; postconditions: EDI = environment
;; preserves:      EAX, EBX, ECX, EDX, EDI (gc), EBP
;; clobbers:       nothing
;; stack usage:    ?
;;
rn_mutate_environment:
    rn_trace configured_debug_environments, 'mutate', hex, edi, hex, eax, lisp, ebx
    cmp al, symbol_tag
    jne .bad_key
    cmp [edi + environment.program], dword tail_env_lookup
    je mutate_list_environment
    cmp [edi + environment.program], dword list_env_lookup
    je mutate_list_environment
    cmp edi, dword private_env_object
    je mutate_private_environment
    mov eax, err_immutable_environment
    jmp rn_error
  .bad_key:
    mov ebx, eax
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error

mutate_private_environment:
    cmp eax, (256 * (1 + private_lookup_table_length))
    ja .private_fail
    push eax
    shr eax, 8
    mov [ground_private_lookup_table + 4 * (eax - 1)], ebx
    pop eax
    ret
  .private_fail:
    mov ebx, eax
    mov eax, err_undefined_private_binding
    mov ecx, inert_tag
    jmp rn_error

mutate_list_environment:
    push edi
    cmp [edi + environment.key0], eax
    je .found
  .next:
    mov edi, [edi + environment.parent]
    cmp [edi + environment.program], dword list_env_lookup
    jne .not_found
    cmp [edi + environment.key0], eax
    jne .next
  .found:
    mov [edi + environment.val0], ebx
    call .capture_edi
    pop edi
    ret
  .not_found:
    pop edi
    call .capture_edi
    push eax
    push ebx
    mov ebx, edi
    call rn_shallow_copy
    mov [edi + environment.program], dword list_env_lookup
    mov [edi + environment.parent], eax
    pop ebx
    pop eax
    mov [edi + environment.key0], eax
    mov [edi + environment.val0], ebx
    ret
  .capture_edi:
    ;; N.B. all list environments are placed on the heap
    cmp edi, [transient_limit]
    jb .drop
    ret
  .drop:
    mov [transient_limit], edi
    ret

