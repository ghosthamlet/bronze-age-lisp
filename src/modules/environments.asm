;;;
;;; environments.asm
;;;
;;; Kernel environment features.
;;;

;;
;; primop_SdefineB (continuation passing procedure)
;;
;; Implementation of ($define! FORMAL EXPR).
;;
;; preconditions:  EBX = argument list = (FORMAL EXPR)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_SdefineB:
    call rn_list_metrics
    test al, al
    jz .error
    test ecx, ecx
    jnz .error
    cmp edx, 2
    jne .error
    mov edx, .next
    call make_helper_continuation
    mov edx, ebx
    mov ebx, car(ebx)
    call rn_check_ptree
    test eax, eax
    jnz .error_ptree
    mov ebx, cdr(edx)
    mov ebx, car(ebx)
    jmp rn_eval
  .next:
    call discard_helper_continuation
    mov ebx, car(ebx)
    mov edx, eax
    call rn_match_ptree_procz
    jnz .match_failure
    mov eax, edi
    call rn_capture
    call rn_bind_ptree
    mov eax, dword inert_tag
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument_structure
  .error_ptree:
    mov ecx, symbol_value(rom_string_SdefineB)
    jmp rn_error
  .match_failure:
    mov eax, err_match_failure
    mov ecx, symbol_value(rom_string_SdefineB)
    jmp rn_error

;;
;; primop_SsetB (continuation passing procedure)
;;
;; Implementation of ($set! ENV FORMAL EXPR).
;;
;; preconditions:  EBX = argument list = (ENV FORMAL EXPR)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_SsetB:
    call rn_list_metrics
    test al, al
    jz .arg_error
    test ecx, ecx
    jnz .arg_error
    cmp edx, 3
    jne .arg_error
    mov edx, .environment_evaluated
    call make_helper_continuation
    mov edx, ebx
    mov ebx, cdr(edx)
    mov ebx, car(ebx)
    call rn_check_ptree
    test eax, eax
    jnz .ptree_error
    mov ebx, car(edx)
    jmp rn_eval
  .environment_evaluated:
    mov edx, eax
    test dl, 3
    jne .env_error
    mov eax, [edx]
    cmp al, environment_header(0)
    jne .env_error
  .evaluate_rhs:
    call rn_force_transient_continuation
    mov [ebp + cont.helper.combination], edx
    mov [ebp + cont.program], dword .rhs_evaluated
    mov ebx, [ebp + cont.helper.ptree]
    mov edi, [ebp + cont.helper.environment]
    mov [ebp + cont.helper.environment], edx
    mov ebx, cdr(ebx)
    mov ebx, cdr(ebx)
    mov ebx, car(ebx)
    jmp rn_eval
  .rhs_evaluated:
    mov edx, eax
    mov edi, [ebp + cont.helper.environment]
    call discard_helper_continuation
    mov ecx, ebx
    mov ebx, cdr(ebx)
    mov ebx, car(ebx)
    call rn_match_ptree_procz
    jnz .match_failure
    mov eax, edi
    call rn_capture
    call rn_bind_ptree
    mov eax, dword inert_tag
    jmp [ebp + cont.program]
  .arg_error:
    mov eax, err_invalid_argument_structure
  .ptree_error:
    mov ecx, symbol_value(rom_string_SsetB)
    jmp rn_error
  .env_error:
    mov eax, err_not_an_environment
    mov ebx, [ebp + cont.helper.ptree]
    mov ecx, symbol_value(rom_string_SsetB)
    jmp rn_error
  .match_failure:
    mov eax, err_match_failure
    mov ebx, ecx
    mov ecx, symbol_value(rom_string_SsetB)
    jmp rn_error

;;
;; primop_Slet1 (continuation passing procedure)
;;
;; Implementation of simple binding form
;;
;;    ($let1 SYMBOL VALUE . BODY)
;;
;; preconditions:  EBX = argument list = (SYMBOL VALUE . BODY)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_Slet1:
    call rn_pairP_procz
    jnz .error
    mov eax, car(ebx)   ; eax = symbol
    cmp al, symbol_tag
    jne .error
    mov eax, cdr(ebx)
    mov ecx, cdr(ebx)   ; expr
    mov edx, ebx
    mov ebx, cdr(eax)   ; body
    call rn_pairP_procz
    mov ebx, edx
    jnz .error
    mov edx, .next
    call make_helper_continuation
    mov ebx, car(ecx)
    jmp rn_eval
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Slet1)
    jmp rn_error
  .next:
    call discard_helper_continuation
    mov edx, eax
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + environment.header], dword environment_header(6)
    mov [eax + environment.program], dword tail_env_lookup
    mov [eax + environment.parent], edi
    mov [eax + environment.val0], edx
    mov edx, car(ebx)
    mov [eax + environment.key0], edx
    mov [eax + environment.key1], edx  ; unused, padding only
    mov edi, eax
    mov ebx, cdr(ebx)
    mov ebx, cdr(ebx)
    jmp primop_Ssequence

;;
;; app_get_current_environment.A0 (continuation passing procedure)
;;
;; Implementation of (get-current-environment)
;;
;; preconditions:  EDI = dynamic environment
;;                 EBP = continuation
;;
app_get_current_environment:
  .A0:
    mov eax, edi
    call rn_capture
    jmp [ebp + cont.program]

;;
;; app_make_kernel_standard_environment.A0 (continuation passing procedure)
;;
;; Implementation of (make-kernel-standard-environment). The
;; environment is not "standard", though.
;;
;; preconditions:  EDI = dynamic environment
;;                 EBP = continuation
;;
app_make_kernel_standard_environment:
  .A0:
    mov ebx, ground_env_object
    call rn_make_list_environment
    jmp [ebp + cont.program]

;;
;; app_eval.A2 (continuation passing procedure)
;;
;; Implementation of (eval OBJECT ENVIRONMENT).
;;
;; preconditions:  EBX = 1st arg = OBJECT
;;                 ECX = 2nd arg = ENVIRONMENT
;;                 EDI = dynamic environment (not used)
;;                 EBP = continuation
;;
app_eval:
  .A2:
    test cl, 3
    jnz .type_error
    mov eax, [ecx]
    cmp al, environment_header(0)
    jne .type_error
    mov edi, ecx
    jmp rn_eval
  .type_error:
    mov eax, err_not_an_environment
    mov ebx, ecx
    mov ecx, symbol_value(rom_string_eval)
    jmp rn_error

;;
;; primop_SbindsP (continuation passing procedure)
;;
;; Implementation of ($binds? EXPR . SYMBOLS)
;;
;; preconditions:  EBX = argument list = (EXPR . SYMBOLS)
;;                 EDI = dynamic environment (not used)
;;                 EBP = continuation
;;
primop_SbindsP:
    test bl, 3
    jz .structure_error
    jnp .structure_error
    mov esi, car(ebx)                ; esi := EXPR
    mov ebx, cdr(ebx)                ; ebx := SYMBOLS
    mov edx, .continue
    call make_helper_continuation    ; save ebx, edi, ebp
    mov ebx, esi                     ; ebx := EXPR
    jmp rn_eval

  .symbol_error:
    pop eax
    pop ebp
  .environment_error:
    mov eax, err_invalid_argument
    jmp .fail
  .structure_error:
    mov eax, err_invalid_argument_structure
  .fail:
    mov ecx, symbol_value(rom_string_SbindsP)
    jmp rn_error

  .continue:
    call discard_helper_continuation
    mov esi, ebx                     ; esi := SYMBOLS
    mov ebx, eax                     ; irritant in case of error
    test al, 3
    jnz .environment_error
    mov edi, eax                     ; edi := evaluated env.
    mov eax, [edi]
    cmp al, environment_header(0)
    jne .environment_error
    mov ebx, esi                     ; ebx := SYMBOLS
    call rn_list_metrics
    mov ebx, esi                     ; irritant in case of error
    test eax, eax
    jz .structure_error
    mov ecx, edx
    jecxz .done                      ; empty list?
    push ebp                         ; save current continuation
    push .yes                        ; [esp] = success address
    lea ebp, [esp - cont.program]    ; pretend it's a cont. object
  .next:
    mov ebx, car(esi)
    cmp bl, symbol_tag
    jne .symbol_error
    mov esi, cdr(esi)                ; advance to next elem.
    push ecx                         ; save local values
    push esi                         ;   ...
    push .no                         ; fail address
    push edi                         ; save starting environment
    jmp [edi + environment.program]
  .yes:
    pop esi
    pop ecx
    loop .next
    pop eax
    pop ebp
  .done:
    mov eax, boolean_value(1)
    jmp [ebp + cont.program]
  .no:
    pop esi
    pop ecx
    pop eax
    pop ebp
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
