;;;
;;; runtime-errors.asm
;;;
;;; Error handling.
;;;

;;
;; rn_backup_cc, rn_restore_cc (irregular procedures)
;;
;; Save and restore the current continuation on stack.
;; The calls to rn_backup_cc and rn_restore_cc can must
;; be paired, but the pairs can be nested.
;;
;; usage:
;;
;;    rn_backup_cc
;;    mov ebp, <some lisp value other than cc>
;;    ...
;;    call rn_allocate
;;    ...
;;    rn_restore_cc
;;
;;
;; Algorihm:
;;
;;   - save EBP on stack (stack is scanned by the GC for roots!)
;;   - store address of the stack slot in [backup_cc_address]
;;   - use [backup_cc_count] to allow nested calls
;;
;; If rn_out_of_memory is called, the error handler dereferences
;; [backup_cc_address] and restores the continuation.
;;
rn_backup_cc:
    push eax
    mov eax, [backup_cc_count]
    test eax, eax
    jz .save
    inc eax
    mov [backup_cc_count], eax
    pop eax
    ret
  .save:
    inc eax
    mov [backup_cc_count], eax
    lea eax, [esp + 4]
    mov [backup_cc_address], eax
    mov eax, [eax]                ; EAX := return address
    xchg [esp], eax               ; EAX := saved eax, [ESP] := ret.addr.
    mov [esp + 4], ebp            ; [ESP+4] := EBP
    ret

rn_restore_cc:
    push eax
    mov eax, [backup_cc_count]
    cmp eax, 1
    jb .error
    je .restore
    dec eax
    mov [backup_cc_count], eax
    pop eax
    ret
  .restore:
    mov eax, [backup_cc_address]
    lea eax, [eax - 8]
    cmp eax, esp
    jne .error
    mov ebp, [eax + 8]
    xor eax, eax
    mov [backup_cc_count], eax
    mov [backup_cc_address], eax
    mov eax, [esp + 4]
    mov [esp + 8], eax
    mov eax, [esp]
    add esp, 8
    ret
  .error:
    mov eax, err_internal_error
    mov ebx, eax
    mov ecx, 0x0E100020
    jmp rn_fatal

;;
;; rn_out_of_memory
;;
;; Error handler for use in native procedures. Discards
;; continuations, which are not needed for correct error
;; handling.
;;
;; preconditions: EAX = error message (lisp string)
;;                EBP = current continuation
;;               [ESP] = caller address (optional)
;;
rn_out_of_memory:
    mov edx, [rn_error_active]
    test edx, edx
    jnz rn_error.double
  .restore_continuation:
    mov edx, [backup_cc_address]
    test edx, edx
    jz .drop_continuation
    mov ebp, [edx]
    xor edx, edx
    mov [backup_cc_address], edx
    mov [backup_cc_count], edx
  .drop_continuation:
    mov ebx, [ebp + cont.header]
    cmp bl, cont_header(0)
    jne .invalid_continuation
    cmp ebp, root_continuation    ; root and error continuation
    je .done                      ;   objects are in read-only
    cmp ebp, error_continuation   ;   memory
    je .done
    mov ebx, [ebp + cont.program]
    cmp ebx, cont_outer           ; inner and outer guard
    je .done                      ;   continuations are necessary
    cmp ebx, cont_inner           ;   for proper error handling
    je .done
    mov ecx, ebp
    mov ebp, [ebp + cont.parent]
    jmp .drop_continuation
  .done:
    mov ebx, inert_tag
    mov ecx, inert_tag
    jmp rn_error
  .invalid_continuation:
    mov ebx, err_internal_error
    jmp rn_fatal

;;
;; rn_error
;;
;; Error handler for use in native procedures.
;;
;; preconditions: EAX = error message (lisp string)
;;                EBX = irritant (lisp object)
;;                ECX = procedure which detected the error (lisp symbol)
;;                EBP = current continuation
;;               [ESP] = caller address (optional)
;;
rn_error:
    mov edx, [rn_error_active]
    test edx, edx
    jnz .double
    mov [rn_error_active], dword 1
    pop edx
    cmp edx, program_segment_base
    jb .discard_invalid_caller_address
    cmp edx, program_segment_limit
    jb .discard_stack
  .discard_invalid_caller_address:
    mov edx, inert_tag
  .discard_stack:
    mov esp, [stack_limit]
    push edx
    push ecx
    push ebx
    push eax
  .force_gc:
    mov edi, [lisp_heap_pointer]
    lea eax, [edi + 8192 + configured_lisp_transient_size + configured_lisp_heap_threshold]
    xor eax, edi
    test eax, 3 | ~(configured_lisp_heap_size - 1)  ; outside fromspace?
    jz .enough
    push ebp
    call gc_collect
    pop ebp
    mov eax, inert_tag
    mov ebx, inert_tag
    mov ecx, inert_tag
    mov edx, inert_tag
  .enough:
    mov esi, inert_tag
    mov edi, inert_tag
  .allocate_error_object:
    mov ecx, (error_header >> 8)
    call rn_allocate
    mov ecx, eax
    mov [ecx + error.header], dword error_header
    pop dword [ecx + error.message]
    pop dword [ecx + error.irritants]
    pop dword [ecx + error.source]
    mov [ecx + error.cc], ebp
    pop eax
    lea eax, [4*eax + 1]
    mov [ecx + error.address], eax
    mov ebx, error_continuation
    mov esp, [stack_limit]
    mov [rn_error_active], dword 0
    jmp rn_apply_continuation
  .double:
    jmp rn_fatal
