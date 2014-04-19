;;;
;;; booleans.asm
;;;
;;; Implementation of boolean features.
;;;

%macro define_Sand_Sor 3
    align 4
primop_%1:
    ;; ebx = argument list
    ;; edi = environment
    ;; ebp = continuation
    pair_nil_cases
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_%1)
    jmp rn_error
  .case.nil:
    mov eax, boolean_value(%3)
    jmp [ebp + cont.program]
  .case.pair:
    mov ecx, ebx
    mov ebx, cdr(ebx)
    cmp bl, nil_tag
    je .tail
    mov edx, .continue
    call make_helper_continuation
    mov ebx, car(ecx)
    jmp rn_eval
  .tail:
    ;; The implementation is not "robust" here. It is not
    ;; checked whether the result is boolean or not.
    mov ebx, car(ecx)
    jmp rn_eval
  .continue:
    call discard_helper_continuation
    cmp eax, boolean_value(%2)
    je .abort
    cmp eax, boolean_value(%3)
    jne .error
    jmp primop_%1
  .abort:
    jmp [ebp + cont.program]
  .error:
    mov ebx, eax
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_%1)
    jmp rn_error
%endmacro

define_Sand_Sor SandP, 0, 1
define_Sand_Sor SorP, 1, 0

app_notP:
  .A1:
    cmp bl, boolean_tag
    jne .error
    mov eax, ebx
    xor ah, 1
    jmp [ebp + cont.program]
  .error:
    mov eax, err_not_bool
    mov ecx, symbol_value(rom_string_notP)
    jmp rn_error

%macro define_and_or 2
app_%1P:
  .A0:
    mov eax, boolean_value(%2)
    jmp [ebp + cont.program]
  .A1:
    cmp bl, boolean_tag
    jne .invalid_argument
    mov eax, ebx
    jmp [ebp + cont.program]
  .A2:
    cmp bl, boolean_tag
    jne .invalid_argument
    cmp cl, boolean_tag
    jne .invalid_argument
    mov eax, ebx
    %1 ah, ch
    jmp [ebp + cont.program]
  .A3:
    cmp bl, boolean_tag
    jne .invalid_argument
    cmp cl, boolean_tag
    jne .invalid_argument
    cmp dl, boolean_tag
    jne .invalid_argument
    mov eax, ebx
    %1 ah, ch
    %1 ah, dh
    jmp [ebp + cont.program]
  .invalid_argument:
    mov eax, err_invalid_argument
    jmp .fail
  .invalid_structure:
    mov eax, err_invalid_argument_structure
  .fail:
    mov ecx, symbol_value(rom_string_%1P)
    jmp rn_error
  .operate:
    mov esi, ebx
    call rn_list_metrics
    test eax, eax
    jz .invalid_structure
    mov ecx, edx
    mov eax, boolean_value(%2)
    jecxz .done
  .next:
    mov ebx, car(esi)
    cmp bl, boolean_tag
    jne .invalid_argument
    mov esi, cdr(esi)
    %1 ah, bh
    loop .next
  .done:
    jmp [ebp + cont.program]
%endmacro

define_and_or and, 1
define_and_or or, 0
