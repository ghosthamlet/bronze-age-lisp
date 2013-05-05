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
;;                   operative.var1 = name
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
    mov ecx, [eax + operative.var1]
    mov eax, err_cannot_traverse
    jmp rn_error

;;
;; app_list_tail, app_list_ref (continuation passing procedures)
;;
;; Implementation of (list-tail START-OBJECT N)
;;               and (list-ref  START-OBJECT N)
;;
;; preconditions:  EBX = START-OBJECT
;;                 ECX = N
;;                 EBP = continuation
;;
;; TODO: bigint???
;;
app_list_tail:
  .A2:
    mov esi, symbol_value(rom_string_list_tail)
    call list_tail_helper
    mov eax, ebx
    jmp [ebp + cont.program]

app_list_ref:
  .A2:
    mov esi, symbol_value(rom_string_list_ref)
    call list_tail_helper
    test bl, 3
    jz list_tail_helper.nonpair
    jnp list_tail_helper.nonpair
    mov eax, car(ebx)
    jmp [ebp + cont.program]

list_tail_helper:
    mov eax, ecx
    xchg ebx, ecx          ; temporarily move to EBX for error reporting
    xor eax, 1
    test eax, 0x80000003
    jnz .invalid_argument
    xchg ebx, ecx
    shr ecx, 2
    jecxz .done
  .next:
    test bl, 3
    jz .nonpair
    jnp .nonpair
    mov ebx, cdr(ebx)
    loop .next
  .done:
    ret
  .invalid_argument:
    mov eax, err_invalid_argument
    jmp .fail
  .nonpair:
    mov eax, err_cannot_traverse
  .fail:
    mov ecx, esi
    jmp rn_error

;;
;; app_set_carB, app_set_cdrB (continuation passing procedures)
;;
;; Implementation of (set-car! PAIR VAL) and (set-cdr! PAIR VAL).
;;
;; preconditions:  EBX = PAIR
;;                 ECX = VAL
;;                 EBP = continuation
;;
app_set_carB:
  .A2:
    mov  edx, ecx
    mov  ecx, symbol_value(rom_string_set_carB)
    mov  eax, ebx
    xor  eax, 0x80000003
    test eax, 0x80000003
    jnz  .error
    mov  car(ebx), edx
    mov  eax, inert_tag
    jmp  [ebp + cont.program]
  .error:
    test bl, 3
    jz .nonpair
    jnp .nonpair
  .immutable:
    mov eax, err_immutable_pair
    jmp rn_error
  .nonpair:
    mov eax, err_invalid_argument
    jmp rn_error

app_set_cdrB:
  .A2:
    mov  edx, ecx
    mov  ecx, symbol_value(rom_string_set_cdrB)
    mov  eax, ebx
    xor  eax, 0x80000003
    test eax, 0x80000003
    jnz  app_set_carB.error
    mov  cdr(ebx), edx
    mov  eax, inert_tag
    jmp  [ebp + cont.program]

;;
;; app_encycleB (continuation passing procedure)
;;
;; Implementation of (encycle! START-OBJECT K1 K2)
;;
;; preconditions:  EBX = START-OBJECT
;;                 ECX = K1
;;                 EDX = K2
;;                 EBP = continuation
app_encycleB:
  .A3:
    mov esi, symbol_value(rom_string_encycleB)
    mov eax, ecx
    xor eax, 1
    test eax, 0x80000003
    jnz .invalid_argument
    mov eax, edx
    xor eax, 1
    test eax, 0x80000003
    jnz .invalid_argument
    cmp edx, fixint_value(0)
    jz .done
    call list_tail_helper
    push ebx
    lea ecx, [edx - 4]
    call list_tail_helper
    test bl, 3
    jz .nonpair
    jnp .nonpair
    pop dword cdr(ebx)
  .done:
    mov eax, inert_tag
    jmp  [ebp + cont.program]
  .invalid_argument:
    jmp list_tail_helper.invalid_argument
  .nonpair:
    jmp list_tail_helper.nonpair

;;
;; app_get_list_metrics (continuation passing procedure)
;;
;; Implementation of (get-list-metrics OBJECT).
;;
;; preconditions:  EBX = OBJECT
;;                 EBP = continuation
;;
app_get_list_metrics:
  .A1:
    call rn_list_metrics
    mov ebx, fixint_value(0)
    test eax, eax
    jz .no_nil                ; improper => number of nils = 0
    test ecx, ecx
    jnz .no_nil               ; cyclic => number of nils = 0
    mov ebx, fixint_value(1)
  .no_nil:
    lea ecx, [4 * ecx + 1]    ; tagged integer ECX = cycle length
    lea edx, [4 * edx + 1]    ; tagged integer EDX = pair count
  .cons:
    push ecx                  ; c = cycle length
    push dword nil_tag
    call rn_cons
    mov esi, edx              ; a = acyclic prefix length
    sub esi, ecx
    inc esi
    push esi
    push eax
    call rn_cons
    push ebx                  ; n = number of nils
    push eax
    call rn_cons
    push edx                  ; p = number of pairs
    push eax
    call rn_cons
    jmp [ebp + cont.program]  ; return (p n a c)

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
    mov eax, einf_value(1)      ; positive infinity
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
;; app_listX.A1 ... .A3, .operate (continuation passing procedures)
;;
;; Implementation of applicative calls
;;
;;   (list* X)
;;   (list* X Y)
;;   (list* X Y Z)
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
    jmp rn_generic_applicative
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
  .operate:
    ;; operative call
    ;; the argument list must not be mutated
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .operate.error
    test ecx, ecx
    jnz .operate.error
    cmp edx, 1
    jb .operate.error
    je .A1
    mov ecx, edx
  .operate.down:
    push dword car(ebx)
    mov ebx, cdr(ebx)
    loop .operate.down
    lea ecx, [edx - 1]
  .operate.up:
    call rn_cons
    push eax
    loop .operate.up
    jmp [ebp + cont.program]
  .operate.error:
    mov eax, err_invalid_argument_structure
    mov ebx, esi
    mov ecx, symbol_value(rom_string_listX)
    jmp rn_error
