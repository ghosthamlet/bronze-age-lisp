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
    lea ecx, [eax + 1]
    mov [eax + environment.hashcode], ecx  ; hash code = initial address
    mov [eax + environment.parent], ebx
    mov ecx, inert_tag
    mov [eax + environment.key0], ecx
    mov [eax + environment.val0], ecx
    pop ecx
    ret

;;
;; rn_make_multiparent_environment (native procedure)
;;
;; Allocate new, persistent, multiparent list environment.
;;
;; preconditions:  ECX = number of parents (untagged)
;;                 ECX >= 2
;;                 [ESP + 4*(ECX-1)] = 1st parent env
;;                 [ESP + 4*(ECX-2)] = 2nd parent env
;;                 [ESP + 0] = last parent
;;
;; postconditions: EAX = new environment
;; preserves:      ECX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX
;; stack usage:    ?
;;
rn_make_multiparent_environment:
    push ecx
    add ecx, 4
    and ecx, ~1
    call rn_allocate
    push edx
    push esi
    push edi
    mov edx, ecx
    shl edx, 8
    mov dl, environment_header(0)
    mov [eax + environment.header], edx
    mov [eax + environment.program], dword multiparent_env_lookup
    lea ebx, [eax + 1]
    mov [eax + environment.hashcode], ebx ; hash code = initial address
    mov ecx, [esp + 3*4]
    test cl, 1
    jnz .copy
    mov [eax + environment.parent + 4*ecx], dword ignore_tag
  .copy:
    lea esi, [esp + 5*4]
    lea edi, [eax + environment.parent]
    rep movsd
    pop edi
    pop esi
    pop edx
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
    je mutate_list_environment.mutate_tail
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
  .mutate_tail:
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

