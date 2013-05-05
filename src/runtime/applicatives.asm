;;;
;;; applicatives.asm
;;;
;;; Wrapped applicatives.
;;;
;;;

;;
;; rn_fully_unwrap (native procedure)
;;
;; Unwrap a combiner.
;;
;; preconditions:  EBX = combiner
;; postconditions: EAX = underlying operative
;;                 EBX = EAX
;;                 ECX = wrap count
;;
;; preserves:      EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EFLAGS
;; stack usage:    1 (incl. call/ret)
;;
rn_fully_unwrap:
    xor ecx, ecx
  .next:
    test bl, 3
    jnz .done
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .done
    inc ecx
    mov ebx, [ebx + applicative.underlying]
    jmp .next
  .done:
    mov eax, ebx
    ret

;;
;; rn_wrap (native procedure)
;;
;; Wrap a combiner into applicative object
;;
;; preconditions:  EBX = combiner
;; postconditions: EAX = applicative
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    14 dwords (incl. call/ret)
;;
rn_wrap:
    push ecx
    mov ecx, 4
    call rn_allocate
    pop ecx
    mov [eax + applicative.header], dword applicative_header(4)
    mov [eax + applicative.program], dword rn_generic_applicative
    mov [eax + applicative.underlying], ebx
    mov [eax + applicative.var0], dword fixint_value(0)
    ret

;;
;; rn_force_transient_continuation (native procedure)
;;
;; Make a copy of current continuation, which can be mutated
;; without impact on the user program, if the current
;; continuation was captured.
;;
;; preconditions:  EBP = continuation
;; postconditions: EBP = continuation which can be mutated
;;
;; preserves:      EDX, ESI, EDI
;; clobbers:       EAX, EBX, ECX, EBP, EFLAGS
;; stack usage:    16 dwords (incl. call/ret)
;;
rn_force_transient_continuation:
    cmp ebp, [transient_limit]
    jae .copy
    ret
  .copy:
    rn_trace configured_debug_evaluator, 'force-transient', hex, ebp, hex, [transient_limit], lisp, eax
    mov ecx, eax
    mov ebx, ebp
    call rn_shallow_transient_copy
    mov ebp, eax
    mov eax, ecx
    ret

;;
;; rn_count_parameters (native procedure)
;;
;; Count parameters
;;
;; preconditions:  EAX = object for error reporting
;;                 EBX = argument list
;;
;; postconditions if the argument is a finite list:
;;                 EBX = argument list
;;                 ECX = list length
;;                 EAX, EDX preserved
;;
;; postconditions if the argument is not a finite list:
;;                 jump to rn_error with ECX set to former EAX
;;
;; preserves: ESI, EDI, EBP
;; clobbers: EAX, EBX, ECX, EDX
;;
rn_count_parameters:
    push eax
    push ebx
    push edx
    call rn_list_metrics
    test eax, eax
    jz .improper
    test ecx, ecx
    jnz .cyclic
    mov ecx, edx
    pop edx
    pop ebx
    pop eax
    ret
  .improper:
  .cyclic:
    pop edx
    pop ebx
    pop ecx
    mov eax, err_invalid_argument_structure
    jmp rn_error

;;
;; rn_generic_applicative (continuation-passing procedure)
;;
;; preconditions: EAX = applicative closure
;;                EBX = argument list
;;                EDI = environment
;;                EBP = current continuation
;;

%define cont.ga.environment  cont.var0
%define cont.ga.combiner     cont.var0 + 4
%define cont.ga.cycle_length cont.var0 + 8
%define cont.ga.pair_count   cont.var0 + 12
%define cont.ga.unevaluated  cont.var0 + 16
%define cont.ga.evaluated    cont.var0 + 20
%define cont.ga.rest         cont.var0 + 24

rn_generic_applicative:
    mov esi, eax
    push ebx
    call rn_list_metrics
    pop ebx
  .with_list_metrics:
    test eax, eax
    jz .improper
    test edx, edx
    jz .noargs
    lea ecx, [4 * ecx + 1]  ; tag
    lea edx, [4 * edx + 1]
    push ecx
    mov ecx, -10
    call rn_allocate_transient
    pop ecx
    mov [eax + cont.header], dword cont_header(10)
    mov [eax + cont.program], dword .cont
    mov [eax + cont.parent], ebp
    mov [eax + cont.ga.environment], edi
    mov [eax + cont.ga.combiner], esi
    mov [eax + cont.ga.cycle_length], ecx
    mov [eax + cont.ga.pair_count], edx
    mov ecx, cdr(ebx)
    mov [eax + cont.ga.unevaluated], ecx
    mov [eax + cont.ga.evaluated], dword nil_tag
    mov [eax + cont.ga.rest], edx
    mov ebp, eax
    mov ebx, car(ebx)
    jmp rn_eval
  .improper:
    mov eax, err_invalid_argument_structure
    mov ecx, esi
    jmp rn_error
  .noargs:
    mov eax, [esi + applicative.underlying]
    jmp rn_combine
  .cont:
    ;rn_trace configured_debug_evaluator, 'ga-cont', lisp, [ebp + cont.ga.unevaluated], lisp, eax, lisp, [ebp + cont.ga.evaluated]
    call rn_force_transient_continuation
    ;rn_trace configured_debug_evaluator, 'ga-cont', hex, ebp, lisp, [ebp + cont.ga.unevaluated], lisp, eax, lisp, [ebp + cont.ga.evaluated]
    mov edi, [ebp + cont.ga.environment]
    push eax
    push dword [ebp + cont.ga.evaluated]
    call rn_cons
    ;rn_trace configured_debug_evaluator, 'ga-cont-cons', hex, ebp, hex, eax, lisp, eax
    mov [ebp + cont.ga.evaluated], eax
    mov ecx, [ebp + cont.ga.rest]
    lea ecx, [ecx - 4]
    cmp ecx, fixint_value(0)
    je .done
    mov [ebp + cont.ga.rest], ecx
    mov eax, [ebp + cont.ga.unevaluated]
    mov ebx, car(eax)
    mov eax, cdr(eax)
    mov [ebp + cont.ga.unevaluated], eax
    ;rn_trace configured_debug_evaluator, 'ga-cont-2', lisp, [ebp + cont.ga.unevaluated], lisp, ebx, lisp, [ebp + cont.ga.evaluated]
    jmp rn_eval
  .done:
    mov ecx, [ebp + cont.ga.cycle_length]
    mov edx, [ebp + cont.ga.pair_count]
    call rn_list_rev_build
    mov eax, [ebp + cont.ga.combiner]
    mov eax, [eax + applicative.underlying]
    mov ebp, [ebp + cont.parent]
    jmp rn_combine
