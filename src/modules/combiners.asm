;;;
;;; combiners.asm
;;;
;;; Kernel combiner features.
;;;

;;
;; primop_Svau (continuation passing procedure)
;;
;; Implementation of ($vau ...).
;;
;; preconditions: EBX = parameter tree = (formals eformal . body)
;;                EDI = static environment
;;                EBP = current continuation
;;
primop_Svau:
    mov edx, ebx                           ; edx := (F E . B)
    jump_if_not_pair dl, .structure_error
    mov ebx, car(edx)                      ; ebx := F
    mov esi, ebx                           ; esi := F
    call rn_check_ptree
    test eax, eax
    jnz .ptree_error
    mov ebx, cdr(edx)                      ; ebx := (E . B)
    jump_if_not_pair bl, .structure_error
    mov eax, car(ebx)                      ; eax := E
    cmp al, symbol_tag
    je .checked
    cmp al, ignore_tag
    jne .structure_error
  .checked:
    mov edx, cdr(ebx)                      ; edx := B
    mov ebx, esi                           ; ebx := F
    mov ecx, eax                           ; ecx := E
    call rn_allocate_closure
    jmp [ebp + cont.program]
  .structure_error:
    mov eax, err_invalid_argument_structure
  .ptree_error: ; message set by rn_check_ptree
    mov ecx, symbol_value(rom_string_Svau)
    jmp rn_error

;;
;; primop_Slambda (continuation passing procedure)
;;
;; Implementation of ($lambda ...).
;;
;; preconditions: EBX = parameter tree = (formals . body)
;;                EDI = static environment
;;                EBP = current continuation
;;
primop_Slambda:
    mov edx, ebx                           ; edx := (F . B)
    jump_if_not_pair dl, .structure_error
    mov ebx, car(edx)                      ; ebx := F
    mov edx, cdr(edx)                      ; edx := B
    ;; try simple cases
    ;;   F = (a)     --> make_bounded_applicative_1
    ;;   F = (a b)   --> make_bounded_applicative_2
    ;;   F = (a b c) --> make_bounded_applicative_3
    jmp try_simple_lambda
  .ordinary:
    call rn_check_ptree
    test eax, eax
    jnz .ptree_error
  .ptree_ok:
    mov ecx, ignore_tag                    ; ecx := #ignore
    call rn_allocate_closure.noenv
    mov ebx, eax
    call rn_wrap
    jmp [ebp + cont.program]
  .structure_error:
    mov eax, err_invalid_argument_structure
  .ptree_error: ; message set by rn_check_ptree
    mov ecx, symbol_value(rom_string_Slambda)
    jmp rn_error

;;
;; try_simple_lambda (irregular procedure)
;;
;; Create lambda object for fast applicative combination
;; evaluation, if the formal parameter tree corresponds
;; to one, two, or three argument procedure.
;;
;; preconditions:   EBX = formal parameter tree
;;                  EDX = procedure body
;;                  EDI = static environment
;;                  EBP = current continuation
;;
;; postconditions:  jump to make_bounded_applicative_1
;;                  or to primop_Slambda.ordinary
;;
;; preserves: EBX, EDX, ESI, EDI, EBP
;; clobbers:  EAX, ECX, EFLAGS
;;
try_simple_lambda:
    test bl, 3
    jz primop_Slambda.ordinary
    jnp primop_Slambda.ordinary
    ;; F = ( ? . ? )
    cmp byte car(ebx), symbol_tag
    jne primop_Slambda.ordinary
    ;; F = ( sym1 . ? )
    mov eax, cdr(ebx)               ; EAX := (cdr F)
    cmp al, nil_tag
    je make_bounded_applicative_1
    test al, 3
    jz primop_Slambda.ordinary
    jnp primop_Slambda.ordinary
    ;; F = ( sym1 ? . ? )
    cmp byte car(eax), symbol_tag
    jne primop_Slambda.ordinary
    ;; F = ( sym1 sym2 . ? )
    mov ecx, cdr(eax)               ; ECX := (cddr F)
    cmp cl, nil_tag
    je .n2
    test cl, 3
    jz primop_Slambda.ordinary
    jnp primop_Slambda.ordinary
    ;; F = ( sym1 sym2 ? . ? )
    cmp byte car(ecx), symbol_tag
    jne primop_Slambda.ordinary
    cmp cdr(ecx), byte nil_tag
    jne primop_Slambda.ordinary
  .n3:
    mov eax, car(eax)
    cmp eax, car(ebx)
    je primop_Slambda.ordinary
    cmp eax, car(ecx)
    je primop_Slambda.ordinary
    mov eax, car(ecx)
    cmp eax, car(ebx)
    je primop_Slambda.ordinary
    jmp make_bounded_applicative_3
  .n2:
    mov eax, car(eax)
    cmp eax, car(ebx)
    je primop_Slambda.ordinary
    jmp make_bounded_applicative_2

app_wrap:
  .A1:
    ;; eax = closure (not used)
    ;; ebx = argument (combiner)
    ;; edi = environment (not used)
    ;; ebp = continuation
    cmp bl, primitive_tag
    jz .ok
    test bl, 3
    jnz .bad
    mov eax, [ebx]
    xor al, operative_header(0)
    test al, ~(operative_header(0) ^ applicative_header(0))
    jnz .bad
  .ok:
    call rn_wrap
    jmp [ebp + cont.program]
  .bad:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_wrap)
    push app_wrap
    jmp rn_error

app_unwrap:
  .A1:
    ;; eax = closure (not used)
    ;; ebx = argument (applicative)
    ;; edi = environment (not used)
    ;; ebp = continuation
    test bl, 3
    jnz .bad
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jnz .bad
    mov eax, [ebx + applicative.underlying]
    jmp [ebp + cont.program]
  .bad:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_unwrap)
    jmp rn_error

;;
;; app_apply (continuation passing procedure)
;;
;; Implementation of (apply COMBINER PTREE)
;;               and (apply COMBINER PTREE ENVIRONMENT)
;;
;; preconditions: EBX = 1st arg = COMBINER
;;                ECX = 2nd arg = PTREE
;;                EDX = 3nd arg = optional ENVIRONMENT
;;                EDI = dynamic environment (not used)
;;                EBP = current continuation
;;
app_apply:
  .A2:
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .error
    mov esi, ebx
    mov ebx, empty_env_object
    call rn_make_list_environment
    mov edi, eax
    mov eax, [esi + applicative.underlying]
    mov ebx, ecx
    jmp rn_combine
  .A3:
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .error
    mov esi, ebx
    mov ebx, edx ; irritant in case of error
    test bl, 3
    jnz .error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .error
    mov edi, edx
    mov eax, [esi + applicative.underlying]
    mov ebx, ecx
    jmp rn_combine

  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_apply)
    jmp rn_error
