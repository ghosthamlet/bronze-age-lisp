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
    mov eax, err_invalid_argument
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

