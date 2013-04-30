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
    call rn_check_ptree
    test eax, eax
    jnz .ptree_error
    mov ecx, ignore_tag                    ; ecx := #ignore
    mov edx, cdr(edx)                      ; edx := B
    call rn_allocate_closure.noenv
    mov ebx, eax
    call rn_wrap
    jmp [ebp + cont.program]
  .structure_error:
    mov eax, err_invalid_argument_structure
  .ptree_error: ; message set by rn_check_ptree
    mov ecx, symbol_value(rom_string_Slambda)
    jmp rn_error

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
