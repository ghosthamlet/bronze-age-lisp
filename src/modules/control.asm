;;;
;;; control.asm
;;;
;;; Implementation of Control module features from the Kernel Report.
;;;
;;; N.B. ($sequence ...) is implemented in runtime/interpreted-operatives.asm.
;;;

%macro define_when_unless 3
    align 4
primop_%1:
    pair_nil_cases
  .case.nil:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_%1)
    jmp rn_error
  .case.pair:
    mov edx, continue_%1
    call make_helper_continuation
    mov ebx, car(ebx)
    jmp rn_eval
  continue_%1:
    mov ebx, eax
    bool_cases
    call discard_helper_continuation
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_%1)
    jmp rn_error
  .case.%2:
    call discard_helper_continuation
    mov ebx, cdr(ebx)
    jmp primop_Ssequence
  .case.%3:
    call discard_helper_continuation
    mov eax, inert_tag
    jmp [ebp + cont.program]
%endmacro

define_when_unless Swhen, true, false
define_when_unless Sunless, false, true

    align 4
primop_Sif:
    ; ebx = argument list
    ; edi = environment
    ; ebp = return
    mov edx, .continue
    call make_helper_continuation
    call rn_list_metrics
    test al, al
    jz .structure_error
    test ecx, ecx
    jnz .structure_error
    cmp edx, 3
    jne .structure_error
    mov ebx, [ebp + cont.helper.ptree]
    mov ebx, car(ebx)
    jmp rn_eval
  .structure_error:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Sif)
    jmp rn_error

  .continue:
    mov ebx, eax
    bool_cases
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_Sif)
    jmp rn_error
  .case.true:
    call discard_helper_continuation
    mov ebx, cdr(ebx)
    mov ebx, car(ebx)
    jmp rn_eval
  .case.false:
    call discard_helper_continuation
    mov ebx, cdr(ebx)
    mov ebx, cdr(ebx)
    mov ebx, car(ebx)
    jmp rn_eval

    align 4
primop_Scond:
    ; ebx = argument list
    ; edi = environment
    ; ebp = return
    mov edx, .continue
    call make_helper_continuation
    call rn_list_metrics
    test al, al
    jz .bad_structure
    test edx, edx
    jz .nil
  .next_clause:
    mov ebx, car(ebx)
    call rn_pairP_procz
    jnz .bad_structure
    mov ebx, car(ebx)
    mov edi, [ebp + cont.helper.environment]
    jmp rn_eval
  .continue:
    mov ebx, eax
    bool_cases
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_Scond)
    jmp rn_error
  .case.true:
    call discard_helper_continuation
    mov ebx, car(ebx)
    mov ebx, cdr(ebx)
    jmp primop_Ssequence
  .case.false:
    call rn_force_transient_continuation
    mov ebx, [ebp + cont.helper.ptree]
    mov ebx, cdr(ebx)
    cmp bl, nil_tag
    je .nil
    mov [ebp + cont.helper.ptree], ebx
    jmp .next_clause
  .nil:
    call discard_helper_continuation
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .bad_structure:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Scond)
    jmp rn_error

;;
;; primop_Smatch (continuation passing procedure)
;;
;; Implementation of ($match EXPR (PTREE1 . BODY1) ...).
;;
primop_Smatch:
    call rn_pairP_procz
    jnz .invalid_argument_structure
    mov esi, ebx
    mov ebx, cdr(ebx)
    mov edx, .continue
    call make_helper_continuation
    mov ebx, car(esi)
    jmp rn_eval
  .invalid_argument_structure:
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Smatch)
    jmp rn_error
  .invalid_ptree:
    mov eax, err_invalid_ptree
    mov ecx, symbol_value(rom_string_Smatch)
    jmp rn_error
  .continue:
    mov esi, eax                              ; ESI := eval'd arg
    mov edi, [ebp + cont.helper.combination]  ; EDI := list of clauses
    mov ebx, edi
    call rn_list_metrics
    test al, al
    jz .invalid_argument_structure
    mov ecx, edx                              ; ECX := no. of clauses
    jecxz .no_match
  .scan:
    mov ebx, car(edi)                         ; EBX := (PTREE . BODY)
    call rn_pairP_procz
    jnz .invalid_argument_structure
    mov ebx, car(ebx)                         ; EBX := PTREE
    call rn_check_ptree
    test eax, eax
    jnz .invalid_ptree
    mov edx, esi                              ; EDX := eval'd arg
    call rn_match_ptree_procz
    jz .match
    mov edi, cdr(edi)                         ; next clause
    loop .scan
  .no_match:
    call discard_helper_continuation
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .match:
    mov ecx, car(edi)                 ; ECX := (PTREE . BODY)
    mov esi, car(ecx)                 ; ESI := PTREE
    mov ecx, cdr(ecx)                 ; ECX := BODY
    call discard_helper_continuation  ; EDI := current env
    mov eax, edi
    call rn_capture
    mov ebx, edi
    call rn_make_list_environment      ; allocate new child env.
    mov edi, eax                       ; set dynamic environment
    mov ebx, esi                       ; EBX := PTREE
    call rn_bind_ptree                 ; bind parameter tree
    mov ebx, ecx                       ; EBX := BODY
    jmp rn_sequence                    ; evaluate in $sequence

;;
;; primop_Smatch_unsafe (continuation passing procedure)
;;
;; Implementation of ($match_unsafe EXPR (PTREE1 . BODY1) ...).
;; Same as $match, except that EXPR is not evaluated and
;; the structure of clauses is NOT checked.
;;
primop_Smatch_unsafe:
    push dword car(ebx)
    mov ebx, cdr(ebx)             ; EBX := list of clauses
    mov esi, ebx                  ; ESI := list of clauses
    call rn_list_metrics
    mov ecx, edx                  ; ECX := no. of clauses
    pop edx                       ; EDX := EXPR
    jecxz .no_match
  .scan:
    mov ebx, car(esi)             ; EBX := (PTREE . BODY)
    mov ebx, car(ebx)             ; EBX := PTREE
    call rn_match_ptree_procz
    jz .match
    mov esi, cdr(esi)             ; ESI := tail of list of clauses
    loop .scan
  .no_match:
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .match:
    mov ecx, car(esi)             ; ECX := (PTREE . BODY)
    mov esi, car(ecx)             ; ESI := PTREE
    mov ecx, cdr(ecx)             ; ECX := BODY
    mov eax, edi                  ; EAX := dynamic environment
    call rn_capture
    mov ebx, edi
    call rn_make_list_environment ; allocate new child env.
    mov edi, eax                  ; set dynamic environment
    mov ebx, esi                  ; EBX := PTREE
    call rn_bind_ptree            ; bind parameter tree
    mov ebx, ecx                  ; EBX := BODY
    jmp rn_sequence               ; evaluate in $sequence
