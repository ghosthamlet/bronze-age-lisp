;;;
;;; pairs.asm
;;;
;;; Elementary operation on pairs and lists.
;;;

;;
;; app_cons (continuation passing procedure)
;;
;; Implementation of (cons X Y).
;;
;; preconditions:  EBX = X
;;                 ECX = Y
;;                 EBP = continuation
;;
app_cons:
  .A2:
    push ebx
    push ecx
    call rn_cons
    jmp [ebp + cont.program]

;;
;; app_cXr.caar (continuation passing procedures)
;;        .cadr
;;        .cdar
;;        .cddr
;;
;; Implementation of (car X), ... (cddr X).
;;
;; preconditions:  EAX = closure
;;                   operative.var2 = name
;;                 EBX = X
;;                 EBP = continuation
;;
app_cXr:
  .caar:
    jump_if_not_pair bl, .error
    mov ebx, car(ebx)
    jmp .car
  .cadr:
    jump_if_not_pair bl, .error
    mov ebx, cdr(ebx)
  .car:
    jump_if_not_pair bl, .error
    mov eax, car(ebx)
    jmp [ebp + cont.program]
 .cdar:
    jump_if_not_pair bl, .error
    mov ebx, car(ebx)
    jmp .cdr
 .cddr:
    jump_if_not_pair bl, .error
    mov ebx, cdr(ebx)
 .cdr:
    jump_if_not_pair bl, .error
    mov eax, cdr(ebx)
    jmp [ebp + cont.program]
 .error:
    mov ecx, [eax + operative.var2]
    mov eax, err_cannot_traverse
    jmp rn_error

;;
;; app_length (continuation passing procedure)
;;
;; Implementation of (cons X Y).
;;
;; preconditions:  EBX = X
;;                 ECX = Y
;;                 EBP = continuation
;;
app_length:
  .A1:
    call rn_list_metrics
    test ecx, ecx
    jnz .cyclic
    lea eax, [1 + 4*edx]
    jmp [ebp + cont.program]
  .cyclic:
    ; TODO: return infinity
    mov eax, 0xFFFFFFFD
    jmp [ebp + cont.program]

;;
;; app_copy_es_immutable.A1 (continuation passing procedures)
;;
;; Implementation of (copy-es-immutable X)
;;
app_copy_es_immutable:
  .A1:
    call rn_copy_es_immutable
    jmp [ebp + cont.program]

;;
;; app_list.A0 ... .A3, .An (continuation passing procedures)
;;
;; Implementation of (list) (list X) (list X Y) (list X Y Z)
;; and (list X Y Z ...).
;;
app_list:
  .A0:
    mov eax, nil_tag
    jmp [ebp + cont.program]
  .A1:
    push ebx
    push dword nil_tag
    call rn_cons
    jmp [ebp + cont.program]
  .A2:
    push ecx
    push dword nil_tag
    call rn_cons
    push ebx
    push eax
    call rn_cons
    jmp [ebp + cont.program]
  .A3:
    push edx
    push dword nil_tag
    call rn_cons
    push ecx
    push eax
    call rn_cons
    push ebx
    push eax
    call rn_cons
    jmp [ebp + cont.program]
  .operate:
    mov eax, ebx
    jmp [ebp + cont.program]

;;
;; app_listX.A1 ... .A3, .An, .On (continuation passing procedures)
;;
;; Implementation of applicative calls
;;
;;   (list* X)
;;   (list* X Y)
;;   (list* X Y Z)
;;   (list* X Y Z ...)
;;
;; and operative call
;;
;;   ((unwrap list*) X Y Z ...)
;;
app_listX:
    mov esi, eax
    push ebx
    call rn_list_metrics
    pop ebx
    test eax, eax
    jz .error
    test ecx, ecx
    jnz .error
    mov eax, esi
    cmp edx, 1
    jb .error
    je rn_asm_applicative.L131
    cmp edx, 2
    je rn_asm_applicative.L132
    cmp edx, 3
    je rn_asm_applicative.L133
    jmp .An
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_listX)
    jmp rn_error
  .A1:
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    push ebx
    push ecx
    call rn_cons
    jmp [ebp + cont.program]
  .A3:
    push ecx
    push edx
    call rn_cons
    push ebx
    push eax
    call rn_cons
    jmp [ebp + cont.program]
  .An:
    ;; applicative call with 4 or more arguments
    ;; the argument list is fresh
    mov eax, err_not_implemented
    jmp rn_error
  .operate:
    ;; operative call
    ;; the argument list must not be mutated
    mov eax, err_not_implemented
    jmp rn_error
