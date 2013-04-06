;;;
;;; environment-lookup.asm
;;;
;;; Lookup of symbols in builtin and list environments.
;;;
;;; The interpreter supports four kinds of environment
;;;
;;;  - table
;;;       - no parents
;;;       - mutable, but set of bound symbols is fixed
;;;       - used for ground and private environments
;;;
;;;  - empty
;;;       - has neither parents nor bindings
;;;       - immutable
;;;       - used as hidden parent for all initially empty envs.
;;;
;;;  - list
;;;       - one parent
;;;       - mutable
;;;
;;;  - multiparent
;;;       - at least 2 parents
;;;       - no bindings
;;;       - immutable
;;;

%define private_binding(string_index) \
  [ground_private_lookup_table + 4*(string_index - 1)]

;;
;; table_lookup_procedure BASE, LENGTH
;;
;; Generates (irregular) continuation-passing procedure which
;; looks up symbol in the builtin environment.
;;
;; preconditions of the procedure:
;;
;;  EBX     = symbol
;;  EDI     = environment
;;  EBP     = success continuation
;;  [ESP]   = saved dynamic environment
;;  [ESP+4] = failure handler
;;
;; usage:
;;   mov ebx, <symbol>
;;   mov edi, <environment>
;;   mov ebp, <success continuation>
;;   push <fail return address>
;;   push edi
;;   jmp [edi + environment.lookup_code]
;;
;; <fail return address>:
;;   symbol in ebx
;;   environment in edi

%macro table_lookup_procedure 2
    cmp ebx, (256 * (1 + %2))
    ja .fail
    mov ecx, ebx
    shr ebx, 8
    mov eax, [%1 + 4 * (ebx - 1)]
    rn_trace configured_debug_environments, 'builtin-found', lisp, ecx, lisp, eax
    pop edi ; restore starting environment
    pop ebx ; discard fail return address
    jmp [ebp + cont.program]
  .fail:
    rn_trace configured_debug_environments, 'builtin-not-found', hex, ebx
    pop edi ; restore starting environment
    ret     ; jump to failure handler
%endmacro

;;
;; ground_env_lookup
;; private_env_lookup
;; list_env_lookup
;; tail_env_lookup
;; empty_env_lookup
;; multiparent_env_lookup

ground_env_lookup:
    table_lookup_procedure ground_private_lookup_table, ground_lookup_table_length

private_env_lookup:
    table_lookup_procedure ground_private_lookup_table, private_lookup_table_length

list_env_lookup:
    nop
tail_env_lookup:
    ;rn_trace 1, 'list-env', hex, edi, lisp, ebx, lisp, [edi + environment.key0]
    cmp ebx, [edi + environment.key0]
    jz .found
    mov edi, [edi + environment.parent]
    mov eax, [edi + environment.program]
    jmp eax
  .found:
    mov eax, [edi + environment.val0]
    pop edi ; restore starting environment
    pop ebx ; discard fail return address
    jmp [ebp + cont.program]

empty_env_lookup:
    pop edi ; restore starting environment
    ret     ; jump to failure handler

multiparent_env_lookup:
    push ebp                       ; save success continuation
    push .success                  ;
    lea ebp, [esp - cont.program]  ; fake continuation
    mov edx, [edi]                 ; header word
    shr edx, 6                     ; get index of last word
    lea edx, [edx - 3]             ;   tagged as fixint
    mov eax, [edi + edx - 1]
    test al, 3
    jz .try_next
    lea edx, [edx - 4]             ; skip pad word
  .try_next:
    push edx                        ; save index
    push .not_found                 ; fail address
    push edi                        ; save this environment
    mov edi, [edi + edx - 1]        ; get K-th parent
    jmp [edi + environment.program] ; lookup in K-th parent
  .not_found:
    pop edx                         ; restore index K
    lea edx, [edx - 4]              ; get (K-1)
    cmp edx, fixint_value(2)        ; at first parent?
    jnz .try_next
  .tail:
    pop eax                             ; discard
    pop ebp                             ; restore continuation
    mov edi, [edi + environment.parent] ; move to first parent
    jmp [edi + environment.program]     ; look up in parent
  .success:
    add esp, 8                    ; discard
    pop ebp                       ; restore continuation
    pop edi                       ; restore starting environment
    pop ebx                       ; discard fail return address
    jmp [ebp + cont.program]      ; jump there
