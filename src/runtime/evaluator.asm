;;;
;;; evaluator.asm
;;;
;;; Kernel evaluator.
;;;
;;; === General register usage ==
;;;
;;;  EAX = result of evaluation
;;;  EBX = expression to evaluate
;;;  ECX = ?
;;;  EDX = ?
;;;  ESI = ?
;;;  EDI = environment
;;;  EBP = current continuation
;;;

%define cont.eval.environment cont.var0
%define cont.eval.combination cont.var1
%define cont.eval.unused      cont.var2

;;
;; rn_eval (continuation passing procedure)
;;
;; Evaluates an object in the dynamic environment.
;;
;; preconditions: EBX = object
;;                EDI = dynamic environment
;;                EBP = continuation
;;
rn_eval:
    rn_trace configured_debug_evaluator, 'eval', hex, ebp, hex, edi, lisp, ebx
    test bl, 3
    jz .self_evaluating
    jp .pair
    cmp bl, symbol_tag
    jne .self_evaluating
  .symbol:
    push .unbound_symbol           ; jump there if lookup fails
    push edi                       ; save original environment
    jmp [edi + environment.program]
  .self_evaluating:
    mov eax, ebx
    jmp [ebp + cont.program]
  .pair:
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.eval.combination], ebx
    mov [eax + cont.eval.environment], edi
    mov [eax + cont.eval.unused], dword inert_tag
    mov ebp, eax
    mov ebx, car(ebx)
    jmp rn_eval
  .unbound_symbol:
    mov eax, err_unbound_symbol
    mov ecx, inert_tag
    push rn_eval
    jmp rn_error
  .continue:
    mov ecx, [ebp + cont.eval.combination]
    mov edi, [ebp + cont.eval.environment]
    mov ebp, [ebp + cont.parent]
    mov ebx, cdr(ecx)
    mov [last_combination], ecx
    jmp rn_combine

;;
;; rn_combine (continuation passing procedure)
;;
;; Combines a combiner with an argument list.
;;
;; preconditions:  EAX = combiner
;;                 EBX = parameter tree
;;                 EDI = environment
;;                 EBP = current continuation
;;
;; postconditions: EAX = combiner (lisp value)
;;                 EBX = parameter tree (lisp value)
;;                 ESI = combiner = EAX
;;                 EDI = environment
;;                 EBP = current continuation
;;                 EIP = combiner program address
;;
rn_combine:
    mov [last_combiner], eax
    mov [last_ptree], ebx
    mov esi, eax
    cmp al, primitive_tag
    je .case.primitive
    test al, 3
    jnz .error
    mov edx, [eax]
    xor dl, operative_header(0)
    test dl, ~(operative_header(0) ^ applicative_header(0))
    jne .error
  .case.closure:
    jmp [eax + operative.program]
  .case.primitive:
    mov edx, eax
    shr edx, 8
    add edx, program_segment_base
    jmp edx
  .error:
    push eax
    push ebx
    call rn_cons
    mov ebx, eax
    mov eax, err_not_a_combiner
    mov ecx, inert_tag
    push dword rn_combine
    jmp rn_error
