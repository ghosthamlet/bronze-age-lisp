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
;; app_setB (continuation passing procedure)
;;
;; Implementation of (set! ENV LHS RHS), the applicative
;; version of $set!.
;;
;; preconditions:  EBX = ENV
;;                 ECX = LHS
;;                 EDX = RHS
;;                 EBP = continuation
;;
app_setB:
  .A3:
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .type_error
    mov edi, ebx
    mov ebx, ecx
    call rn_check_ptree
    test eax, eax
    jnz .ptree_error
    call rn_match_ptree_procz
    jnz .match_failure
    call rn_bind_ptree
    mov eax, dword inert_tag
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_not_an_environment
  .ptree_error:
    mov ecx, symbol_value(rom_string_setB)
    jmp rn_error
  .match_failure:
    mov eax, err_match_failure
    mov ecx, symbol_value(rom_string_setB)
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
;; aux_map_car_cadr (native procedure)
;;
;; Construct list of CARs and CADRs from a given list.
;;
;; preconditions:  ESI = input list
;;                 ECX = N > 0, input list length (untagged integer)
;;
;; postconditions: EAX = list of CARs
;;                 EDX = list of CADRs
;;
;; preserves:      EBX, ECX, ESI, EDI, EBP
;; clobbers:       EAX, EDX, EFLAGS
;; stack usage:    ?
;;
aux_map_car_cadr:
    push ebx
    push ecx
    push esi
    push edi
    shl ecx, 2              ; allocate 4*N dwords
    call rn_allocate        ;   for two lists of length N
    lea edi, [2 * ecx]      ; stride between two output lists
    shr ecx, 2              ; ECX = N
    push eax                ; save head of original list
  .next:
    mov ebx, car(esi)        ; next element of input list
    test bl, 3               ; check type
    jz .error
    jnp .error
    mov edx, car(ebx)        ; copy CAR field
    mov [eax], edx           ;   ...
    lea edx, [eax + 8]       ; get pointer to next element
    shr edx, 1               ;   of 1st output list
    or  edx, 0x80000003      ; tag as mutable pair
    mov [eax + 4], edx       ; store in CDR field of output element
    mov ebx, cdr(ebx)        ; get CDR of input element
    test bl, 3               ; check type
    jz .error                ;   ...
    jnp .error               ;   ...
    mov ebx, car(ebx)        ; get CADR of input element
    lea edx, [eax + edi + 8] ; get pointer to next element
    shr edx, 1               ;   of 2nd output list
    or  edx, 0x80000003      ; tag as mutable pair
    mov [eax + edi], ebx     ; store CAR field
    mov [eax + edi + 4], edx ; store CDR field
    mov esi, cdr(esi)        ; move to next input element
    lea eax, [eax + 8]       ; move to next output element
    loop .next
    mov ecx, nil_tag
    mov [eax - 4], ecx       ; terminate 1st list with nil
    mov [eax + edi - 4], ecx ; terminate 2nd list with nil
    pop eax                  ; head of 1st list
    lea edx, [eax + edi]     ; head of 2nd list
    shr eax, 1               ; tag both as mutable pairs
    shr edx, 1
    or  eax, 0x80000003
    or  edx, 0x80000003
    pop edi
    pop esi
    pop ecx
    pop ebx
    ret
  .error:
    mov eax, err_cannot_traverse
    mov ebx, esi
    mov ecx, symbol_value(rom_string_Sletrec) ;; TODO: replace hardwired symbol with a parameter
    push .error
    jmp rn_error

;;
;; primop_Slet, primop_Sletrec,
;;             primop_Slet_safe (continuation passing procedures)
;;
;; Implementation of ($letrec BINDINGS . BODY)
;;               and ($let BINDINGS . BODY)
;;
;; preconditions:  EBX = argument list = (BINDINGS . BODY)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_Sletrec:
    mov esi, ebx                  ; ESI = (BINDINGS . BODY)
    mov eax, edi                  ; capture the dynamic
    call rn_capture               ;   environment
    mov ebx, edi                  ; create child
    call rn_make_list_environment ;   of the dynamic environment
    mov ebx, esi                  ; EBX = (BINDINGS . BODY)
    push eax                      ; environment "R" = child
    push eax                      ; environment "L" = child
    push dword symbol_value(rom_string_Sletrec)
    jmp aux_let_common

primop_Slet:
    mov esi, ebx                  ; ESI = (BINDINGS . BODY)
    mov eax, edi                  ; capture the dynamic
    call rn_capture               ;    environment
    mov ebx, edi                  ; create child
    call rn_make_list_environment ;   of the dynamic environment
    mov ebx, esi                  ; EBX = (BINDINGS . BODY)
    push edi                      ; environment "R" = parent
    push eax                      ; environment "L" = child
    push dword symbol_value(rom_string_Slet)
    jmp aux_let_common

primop_Slet_safe:
    mov esi, ebx                  ; ESI = (BINDINGS . BODY)
    mov ebx, ground_env_object    ; create new standard
    call rn_make_list_environment ;   environment
    mov ebx, esi                  ; EBX = (BINDINGS . BODY)
    push edi                      ; environment "R" = dynamic env
    push eax                      ; environment "L" = new std. env
    push dword symbol_value(rom_string_Slet_safe)
    jmp aux_let_common

;;
;; primop_Slet_redirect (continuation passing procedure)
;;
;; Implementation of ($let-redirect ENV BINDINGS . BODY)
;;
;; preconditions:  EBX = argument list = (ENV BINDINGS . BODY)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_Slet_redirect:
    test bl, 3
    jz .invalid_structure
    jnp .invalid_structure
    mov esi, car(ebx)
    mov ebx, cdr(ebx)
    mov edx, .continue
    call make_helper_continuation
    mov ebx, esi
    jmp rn_eval
  .invalid_structure:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Slet_redirect)
    jmp rn_error
  .invalid_type:
    mov eax, err_not_an_environment
    mov ecx, symbol_value(rom_string_Slet_redirect)
    jmp rn_error
  .continue:
    call discard_helper_continuation
    mov esi, ebx                   ; ESI = (BINDINGS . BODY)
    mov ebx, eax                   ; EBX = evaluated env. argument
    test bl, 3                     ; check type
    jnz .invalid_type
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .invalid_type
    call rn_make_list_environment  ; create child env.
    mov ebx, esi                   ; EBX = (BINDINGS . BODY)
    push edi                       ; environment "R" = dynamic env
    push eax                       ; environment "L" = child of arg
    push dword symbol_value(rom_string_Slet_redirect)
    jmp aux_let_common

;;
;; aux_let_common (continuation passing procedure)
;;
;; Implementats common part of $let, $letrec, $let-redirect
;; and $let-safe.
;;
;; Evaluates right hand sides of bindings in environment "R",
;; binds the left hand sides in environment "L" and evaluates
;; the body in the environment "L".
;;
;; preconditions:  EBX = (BINDINGS . BODY)
;;                 EBP = current continuation
;;           [ESP + 0] = symbol for error reporting
;;           [ESP + 4] = environment "L"
;;           [ESP + 8] = environment "R"
;;
aux_let_common:
    test bl, 3                    ; check argument list
    jz .invalid_structure
    jnp .invalid_structure
    mov esi, cdr(ebx)             ; ESI = BODY
    mov ebx, car(ebx)             ; EBX = BINDINGS
    call rn_list_metrics
    test eax, eax                 ; BINDINGS improper list?
    jz .invalid_structure
    test ecx, ecx                 ; BINDINGS cyclic?
    jnz .invalid_structure
    test edx, edx                 ; BINDINGS empty?
    jz .empty
    ;; TODO: special case length=1, ($letrec ((X Y)) . T)
    mov ecx, edx                  ; ECX = length of BINDINGS
    xchg ebx, esi                 ; EBX = BODY, ESI = BINDINGS
    call aux_map_car_cadr         ; EDX = rhs := (map cadr BINDINGS)
    mov ecx, eax                  ; ECX = lhs := (map car BINDINGS)
    mov esi, ebx                  ; ESI = BODY
    mov ebx, ecx                  ; EBX = lhs
    call rn_check_ptree           ; is (map car BINDINGS)
    test eax, eax                 ;   valid ptree?
    jnz .fail                     ;   ...
    mov ebx, ecx                  ; EBX = lhs
    mov ecx, -8
    call rn_allocate_transient
    pop ecx                       ; ECX = symbol for error reporting
    pop edi                       ; EDI = environment "L"
    mov [eax + cont.header], dword cont_header(8)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], edi    ; environment "L"
    mov [eax + cont.var1], ebx    ; lhs
    mov [eax + cont.var2], esi    ; body of $letrec form
    mov [eax + cont.var3], ecx    ; symbol for error reporting
    mov [eax + cont.var4], ecx    ; padding
    mov ebp, eax
    mov eax, private_binding(rom_string_list)
    mov ebx, edx
    pop edi                       ; EDI = environment "R"
    jmp rn_combine                ; evaluate (list . rhs)
  .invalid_structure:
    mov eax, err_invalid_argument_structure
  .fail:
    pop ecx
    pop edx
    pop edx
    jmp rn_error
  .match_failure:
    mov eax, err_match_failure
    mov ecx, [ebp + cont.var3]
    jmp rn_error
  .empty:
    pop eax                       ; discard environment "R"
    pop edi                       ; EDI = environment "L"
    pop eax                       ; discard operative name
    mov ebx, esi                  ; EBX = BODY of let form
    jmp rn_sequence
  .continue:
    mov edi, [ebp + cont.var0]   ; EDI = environment
    mov ebx, [ebp + cont.var1]   ; EBX = lhs
    mov esi, [ebp + cont.var2]   ; ESI = body of $letrec
    mov ebp, [ebp + cont.parent] ; restore original continuation
    mov edx, eax                 ; EDX = result of (list . rhs)
    call rn_match_ptree_procz    ; check
    jnz .match_failure
    call rn_bind_ptree           ; bind lhs <- rhs
    mov ebx, esi                 ; EBX = body of $letrec
    jmp rn_sequence

;;
;; primop_SletX (continuation passing procedure)
;;
;; Implementation of ($let* BINDINGS . BODY)
;;
;; preconditions:  EBX = argument list = (BINDINGS . BODY)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
primop_SletX:
    test bl, 3                    ; check argument list
    jz .invalid_structure
    jnp .invalid_structure
    mov esi, cdr(ebx)             ; ESI = BODY
    mov ebx, car(ebx)             ; EBX = BINDINGS
    call rn_list_metrics
    test eax, eax                 ; BINDINGS improper list?
    jz .invalid_structure
    test ecx, ecx                 ; BINDINGS cyclic?
    jnz .invalid_structure
    test edx, edx                 ; BINDINGS empty?
    jz .empty
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], dword .continue
    mov [eax + cont.parent], ebp
    mov [eax + cont.var0], edi    ; dynamic environment
    mov [eax + cont.var1], ebx    ; BINDINGS = ((L1 R1) . T)
    mov [eax + cont.var2], esi    ; BODY
    mov ebp, eax
    mov ebx, car(ebx)             ; EBX = (L1 R1)
    test bl, 3                    ; check structure of binding
    jz .invalid_structure
    jnp .invalid_structure
    mov ebx, cdr(ebx)             ; EBX = (R1)
    test bl, 3                    ; check structure of binding
    jz .invalid_structure
    jnp .invalid_structure
    mov ebx, car(ebx)             ; EBX = R1
    jmp rn_eval
  .empty:
    mov eax, edi                  ; capture dynamic environment
    call rn_capture               ;  (in case it is allocated by, e.g. $let1)
    mov ebx, edi                  ; create child
    call rn_make_list_environment ;   of the dynamic environment
    mov edi, eax                  ; EDI = the new environment
    mov ebx, esi                  ; EBX = body of ($letrec () . BODY)
    jmp rn_sequence
  .invalid_structure:
    mov eax, err_invalid_argument_structure
  .fail:
    mov ecx, symbol_value(rom_string_SletX)
    jmp rn_error
  .match_failure:
    mov eax, err_match_failure
    jmp .fail
  .continue:
    mov edx, eax                     ; EDX = evaluated R1
    mov ebx, [ebp + cont.var0]       ; EBX = parent environment
    mov eax, ebx                     ; capture dynamic environment
    call rn_capture                  ;  (in case it was created by e.g. $let1)
    call rn_make_list_environment
    mov edi, eax                     ; EDI = child environment
    mov ebx, [ebp + cont.var1]       ; EBX = ((L1 R1) . T)
    mov ebx, car(ebx)                ; EBX = (L1 R1)
    test bl, 3                       ; paranoid check
    jz .invalid_structure            ;  in case the list was mutated
    jnp .invalid_structure           ;  TODO: copy-es-immutable ?
    mov ebx, car(ebx)                ; EBX = L1
    call rn_check_ptree
    test eax, eax
    jnz .fail
    call rn_match_ptree_procz
    jnz .match_failure
    call rn_bind_ptree
    mov edx, [ebp + cont.var1]      ; EDX = ((L1 R1) . T)
    mov edx, cdr(edx)               ; EDX = T = ((L2 R2) ...)
    cmp edx, nil_tag
    jz .done
    test dl, 3                      ; paranoid check
    jz .invalid_structure
    jnp .invalid_structure
    call rn_force_transient_continuation
    mov [ebp + cont.var0], edi
    mov [ebp + cont.var1], edx
    mov ebx, car(edx)               ; EBX = (L2 R2)
    test bl, 3                      ; check structure
    jz .invalid_structure           ;  of next binding
    jnp .invalid_structure
    mov ebx, cdr(ebx)               ; EBX = (R2)
    test bl, 3                      ; check binding structure
    jz .invalid_structure
    jnp .invalid_structure
    mov ebx, car(ebx)               ; EBX = R2
    jmp rn_eval
  .done:
    mov ebx, [ebp + cont.var2]      ; EBX = body
    mov ebp, [ebp + cont.parent]    ; original continuation
    jmp rn_sequence

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
;; app_make_environment (continuation passing procedures)
;;
;; Implementation of (make-environment),
;;                   (make-environment E1),
;;                   (make-environment E1 E2),
;;               and (make-environment E1 E2 E3...).
;;
;; preconditions:  EDI = dynamic environment (not used)
;;                 EBP = continuation
;;  for .A1, .A2:  EBX = 1st arg = first parent
;;       for .A2:  ECX = 2nd arg = second parent
;;  for .operate:  EBX = argument list
;;
app_make_environment:
  .A0:
    mov ebx, empty_env_object
    call rn_make_list_environment
    jmp [ebp + cont.program]
  .A1:
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .type_error
    call rn_make_list_environment
    jmp [ebp + cont.program]
  .A2:
    test bl, 3
    jnz .type_error
    test cl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .type_error
    mov eax, [ecx]
    cmp al, environment_header(0)
    jne .type_error
    push ebx
    push ecx
    mov ecx, 2
    call rn_make_multiparent_environment
    mov ebx, eax
    call rn_make_list_environment
    add esp, 8
    jmp [ebp + cont.program]
  .operate:
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .structure_error
    cmp edx, 1
    jb .A0
    mov ebx, car(esi)
    je .A1
    mov ecx, edx
  .L:
    mov ebx, car(esi)
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, environment_header(0)
    jne .type_error
    push ebx
    mov esi, cdr(esi)
    loop .L
    mov ecx, edx
    call rn_make_multiparent_environment
    mov ebx, eax
    call rn_make_list_environment
    lea esp, [esp + 4*edx]
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_make_environment)
    jmp rn_error
  .structure_error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_make_environment)
    jmp rn_error

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
