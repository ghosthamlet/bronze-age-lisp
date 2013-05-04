;;;
;;; guarded-continuations.asm
;;;
;;; Guarded continuations, selection and interception.
;;;
;;; The applicative guard-continuation (and guard-dynamic-extent)
;;; creates a pair of "guard" continuation objects:
;;;
;;;  - the inner continuation (which contains the exit guards)
;;;  - the outer continuation (which contains the entry guards)
;;;
;;; When the control is abnormaly passed to a continuation,
;;; a path from the source to the destination continuation
;;; is determined. If the path contains guard continuations,
;;; a chain of "intercept" continuations is created.
;;;
;;; Layout of "guard" continuation objects:
;;;
;;; offset
;;;       0   cont_header(4 + 2*N)      (header)
;;;       4   cont_inner or cont_outer  (program)
;;;       8   parent continuation
;;;      12   environment
;;;      16   selector[0]
;;;      20   interceptor[0]            (operative)
;;;           ...
;;;   8+8*N   selector[N-1]
;;;  12+8*N   interceptor[N-1]
;;;
;;; Layout of "intercept" continuation objects:
;;;
;;; offset
;;;       0   cont_header(6)
;;;       4   cont_intercept or cont_intercept_last
;;;       8   outer continuation
;;;      12   environment
;;;      16   next continuation
;;;      20   interceptor operative
;;;

%define cont.guard.environment      cont.var0
%define cont.guard.selector0        cont.var1
%define cont.intercept.environment  cont.var0
%define cont.intercept.next         cont.var1
%define cont.intercept.operative    cont.var2

cont_inner:
    mov ebp, [ebp + cont.parent]
    jmp [ebp + cont.program]

cont_outer:
    mov ebp, [ebp + cont.parent]
    jmp [ebp + cont.program]

cont_intercept:
    ;; eax = value
    ;; ebp = interceptor continuation
    ;;  .parent = outer cont.
    ;;  .intercept.operative = interceptor
    ;;  .intercept.next = next continuation in interceptor chain
    ;;
    mov ebp, [ebp + cont.intercept.next]
  .call_interceptor:
    mov edx, eax
    mov ebx, [ebp + cont.parent]
    call rn_continuation_applicative
    push eax
    push dword nil_tag
    call rn_cons
    push edx
    push eax
    call rn_cons
    mov ebx, eax
    mov eax, [ebp + cont.intercept.operative]
    mov edi, [ebp + cont.intercept.environment]
    jmp rn_combine

cont_intercept_last:
    mov ebp, [ebp + cont.intercept.next]
  .go:
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    mov esp, [stack_limit]
    jmp [ebp + cont.program]

;;
;; rn_select_one (native procedure)
;;
;; Find interceptor in guard continuation.
;;
;; preconditions:  EBX = guard continuation
;;                 ECX = target continuation
;; postconditions if the guard continuation selects the target:
;;                 ZF = 1
;;                 EAX = interceptor
;;                 EDI = environment
;; postconditions otherwise:
;;                 ZF = 0
;;                 EAX = nil
;;
;; preserves:      EBX, ECX, EDX, ESI, EBP
;; clobbers:       EAX, EDI
;; stack usage:    5 (incl. call/ret)
;;
rn_select_one:
    push ebx
    push esi
    mov edi, [ebx]
    shr edi, 8
    lea edi, [ebx + 4 * edi]
    lea esi, [ebx + cont.guard.selector0]
    jmp .cond
  .next_selector:
    mov eax, ecx
    mov ebx, [esi]
    call rn_descendantP_procz
    jz .found
    lea esi, [esi + 8]
  .cond:
    cmp esi, edi
    jnz .next_selector
  .not_found:
    xor eax, eax
    xor al, nil_tag ; set ZF = 0
    pop esi
    pop ebx
    ret
  .found:
%if configured_debug_continuations
    rn_trace configured_debug_continuations, 'select', hex, eax, hex, ebx, hex, [esi + 4]
    xor eax, eax ; fix ZF after debug print
%endif
    mov eax, [esi + 4]
    pop esi
    pop ebx
    mov edi, [ebx + cont.guard.environment]
    ret

;;
;; rn_select_exit_guards (native procedure)
;;
;; Builds chain of exit interceptors.
;;
;; preconditions:  EBX = source continuation
;;                 ECX = destination continuation
;;                 EDX = common ancestor of source and destination
;;                 ESI = continuation chain head
;;
;; postconditions: [original ESI + cont.var1] = pointer to first continuation in the chain
;;                 ESI = pointer to last continuation in the chain
;; preserves:      ECX, EDX, EBP
;; clobbers:       EAX, EBX, ESI, EDI
;;
rn_select_exit_guards:
    jmp .compare
  .done:
    ret
  .next:
    mov ebx, [ebx + cont.parent]
  .compare:
    rn_trace configured_debug_continuations, 'x', hex, ebx
    cmp ebx, edx
    je .done
    cmp [ebx + cont.program], dword cont_inner
    jne .next
  .inner:
    call rn_select_one
    jnz .next
    push eax                      ; save interceptor
    mov ebx, [ebx + cont.parent]  ; get outer cont.
    push ecx
    mov ecx, 6
    call rn_allocate
    pop ecx
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword cont_intercept
    mov [eax + cont.parent], ebx
    mov [eax + cont.intercept.environment], edi
    pop dword [eax + cont.intercept.operative]
    mov [eax + cont.intercept.next], dword inert_tag
    mov [esi + cont.intercept.next], eax
    mov esi, eax
    jmp .next

;;
;; rn_select_entry_guards (native procedure)
;;
;; Build chain of entry interceptors.
;;
;; preconditions:  EBX = destination continuation
;;                 ECX = source continuation
;;                 EDX = common ancestor of source and destination
;;                 ESI = tail of interceptor chain
;;
;; postconditions: ESI = head of interceptor chain
;;
;; preserves:      ECX, EDX, EBP
;; clobbers:       EAX, EBX, ESI, EDI
;;
rn_select_entry_guards:
    jmp .compare
  .done:
    ret
  .next:
    mov ebx, [ebx + cont.parent]
  .compare:
    rn_trace configured_debug_continuations, 'n', hex, ebx
    cmp ebx, edx
    je .done
    cmp [ebx + cont.program], dword cont_outer
    jne .next
  .outer:
    call rn_select_one
    jnz .next
    rn_trace configured_debug_continuations, 'entry-guard', hex, ebx
    push eax    ; save interceptor
    push ecx    ; save target
    mov ecx, 6
    call rn_allocate
    pop ecx
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword cont_intercept
    mov [eax + cont.parent], ebx
    mov [eax + cont.intercept.environment], edi
    pop dword [eax + cont.intercept.operative]
    mov [eax + cont.intercept.next], esi
    mov esi, eax
    jmp .next

;;
;; rn_select_all_guards (native procedure)
;;
;; Build chain of entry and exit interceptors.
;;
;; preconditions:  EAX = source continuation
;;                 EBX = destination continuation
;;
;; postconditions: EAX = EBX = head of interceptor chain
;;
;; preserves:      ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX
;;
rn_select_all_guards:
    push esi
    push edx
    push ecx
    push eax
    push ebx
    push dword inert_tag
    push dword inert_tag
    ;; [esp + 0]  = exit list tail ptr
    ;; [esp + 4]  = exit list head
    ;; [esp + 8]  = destination
    ;; [esp + 12] = source
    call rn_common_ancestor
    mov edx, eax
    mov ebx, [esp + 12]
    mov ecx, [esp + 8]
    lea esi, [esp + 4 - cont.intercept.next]  ; virtual head
    call rn_select_exit_guards
    mov [esp], esi
    mov ebx, [esp + 8]
    mov ecx, [esp + 12]
    mov esi, ebx
    call rn_select_entry_guards
    mov ebx, [esp]
    mov [ebx + cont.intercept.next], esi ; virtual head
    mov eax, [esp + 4]
    mov ebx, eax
    add esp, 16
    pop ecx
    pop edx
    pop esi
    ret

;;
;; rn_change_last_interceptor (native procedure)
;;
;; Mark the penultimate element in chain of interceptor
;; continuations.
;;
;; preconditions:  EAX = first continuation in the chain
;;                 EBX = last element
;;
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBp
;; clobbers:       EFLAGS
;;
rn_change_last_interceptor:
    push eax
    push edx
  .next:
    mov edx, eax
    mov eax, [eax + cont.intercept.next]
    cmp eax, ebx
    jne .next
    mov [edx + cont.program], dword cont_intercept_last
    pop edx
    pop eax
    ret

;;
;; rn_apply_continuation (continuation passing procedure)
;;
;; Abnormally pass value to a continuation.
;;
;; preconditions:  EBX = target continuation
;;                 ECX = value
;;                 EBP = source continuation (source cont.)
;;
rn_apply_continuation:
    mov eax, ebp
    call rn_capture
    push ebx
    call rn_select_all_guards
    pop ebx
    cmp ebx, eax
    je .no_interceptors
    call rn_change_last_interceptor
    mov ebp, eax
    mov eax, ecx
    jmp cont_intercept.call_interceptor
  .no_interceptors:
    mov ebp, eax
    mov eax, ecx
    jmp cont_intercept_last.go

;;
;; rn_continuation_applicative (native procedure)
;;
;; Create applicative object from a continuation.
;;
;; preconditions:  EBX = continuation
;; postconditions: EAX = singly wrapped applicative
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;;
rn_continuation_applicative:
    ;; ebx = continuation
    push ebx
    push ecx
    mov ecx, 4
    call rn_allocate
    mov [eax + operative.header], dword operative_header(4)
    mov [eax + operative.program], dword .operate
    mov [eax + operative.var0], ebx
    mov [eax + operative.var1], dword inert_tag
    mov ebx, eax
    call rn_wrap
    pop ecx
    pop ebx
    ret
    align 4
  .operate:
    mov ecx, ebx
    mov ebx, [eax + operative.var0]
    jmp rn_apply_continuation
