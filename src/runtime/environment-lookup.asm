;;;
;;; environment-lookup.asm
;;;
;;; Lookup of symbols in builtin and list environments.
;;;

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
;;

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
