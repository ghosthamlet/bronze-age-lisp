;;;
;;; iterations.asm
;;;
;;; Implementation of (map F L1 L2...) and (for-each F L1 L2...).
;;; The simple cases (map F XS) and (for-each F XS), where XS
;;; is finite list, are implemented in assembly. The difficult
;;; cases involving cyclic lists is implemented in lisp.
;;;

app_map:
  .A2:
    push ebx
    push ecx
    mov esi, symbol_value(rom_string_map)
    call aux_check_two_argument_map
    test edx, edx
    jz .empty
    test ecx, ecx
    jnz .cyclic
    add esp, 8
    push aux_map_simple.map.continue
    jmp aux_map_simple
  .empty:
    add esp, 8
    mov eax, nil_tag
    jmp [ebp + cont.program]
  .cyclic:
    push dword nil_tag       ; 2nd arg already on the stack
    call rn_cons
    push eax                 ; 1st arg already on the stack
    call rn_cons
    mov ebx, eax
  .operate:
    mov eax, private_binding(rom_string_general_map)
    mov eax, [eax + applicative.underlying]
    jmp rn_combine

app_for_each:
  .A2:
    mov esi, symbol_value(rom_string_for_each)
    call aux_check_two_argument_map
    test edx, edx
    jz .empty
    push aux_map_simple.foreach.continue
    jmp aux_map_simple
  .empty:
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .operate:
    mov eax, private_binding(rom_string_general_for_each)
    mov eax, [eax + applicative.underlying]
    jmp rn_combine

;;
;; aux_check_two_argument_map (native procedure)
;;
;; Type checking for two-argument call (map ...) and (for-each ...).
;;
;; preconditions:  EBX = combiner (1st argument)
;;                 ECX = list (2nd argument)
;;                 ESI = symbol for error reporting
;;
;; postconditions: EBX = list (2nd argument)
;;                 ESI = unwrapped combiner
;;                 ECX = cycle length
;;                 EDX = number of pairs in the list
;;
;; preserves:      EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EFLAGS
;;
aux_check_two_argument_map:
    push esi
    test bl, 3
    jnz .invalid_argument
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .invalid_argument
    mov ebx, [ebx + applicative.underlying]
    cmp bl, primitive_tag
    je .combiner_ok
    mov eax, [ebx]
    cmp al, applicative_header(0)
    je .invalid_argument
  .combiner_ok:
    mov esi, ebx
    mov ebx, ecx
    push ebx
    call rn_list_metrics
    pop ebx
    test eax, eax
    jz .invalid_argument
    pop eax
    ret
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, [esp]
    mov [esp], dword .invalid_argument
    jmp rn_error

;;
;; aux_map_simple (continuation passing procedure)
;;
;; Implementation of two-argument call to for-each or map.
;;
;; preconditions:  EBX = list (2nd argument)
;;                 EDX = length of list (untagged integer), EDX > 0
;;                 ESI = unwrapped combiner (1st argument)
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;               [ESP] = aux_map.foreach.continue or aux_map.map.continue
;;
%define cont.map.environment cont.var0
%define cont.map.combiner    cont.var1
%define cont.map.length      cont.var2
%define cont.map.list        cont.var3
%define cont.map.accumulator cont.var4
aux_map_simple:
  .init:
    mov ecx, -8
    call rn_allocate_transient
    mov ecx, cdr(ebx)
    mov ebx, car(ebx)
    lea edx, [4 * edx - 3]
    mov [eax + cont.header], dword cont_header(8)
    pop dword [eax + cont.program]
    mov [eax + cont.parent], ebp
    mov [eax + cont.map.environment], edi
    mov [eax + cont.map.combiner], esi
    mov [eax + cont.map.length], edx
    mov [eax + cont.map.list], ecx
    mov [eax + cont.map.accumulator], dword nil_tag
    mov ebp, eax
    push ebx
    push dword nil_tag
    call rn_cons
    mov ebx, eax
    mov eax, esi
    jmp rn_combine
  .map.evaluated:
    mov esi, [ebp + cont.map.accumulator]
    mov ebp, [ebp + cont.parent]
    push eax
    push nil_tag
    call rn_cons
    cmp esi, nil_tag
    je .map.reversed
  .map.reverse:
    push dword car(esi)
    push eax
    call rn_cons
    mov esi, cdr(esi)
    cmp esi, nil_tag
    jne .map.reverse
  .map.reversed:
    jmp [ebp + cont.program]
  .map.continue:
    mov edx, [ebp + cont.map.length]
    cmp edx, fixint_value(0)
    je .map.evaluated
    call rn_force_transient_continuation
    push eax
    push dword [ebp + cont.map.accumulator]
    call rn_cons
    mov [ebp + cont.map.accumulator], eax
  .next:
    mov edi, [ebp + cont.map.environment]
    mov ecx, [ebp + cont.map.list]
    push dword car(ecx)
    push dword nil_tag
    call rn_cons
    mov ebx, eax
    mov eax, [ebp + cont.map.combiner]
    mov ecx, cdr(ecx)
    lea edx, [edx - 4]
    mov [ebp + cont.map.length], edx
    mov [ebp + cont.map.list], ecx
    jmp rn_combine
  .foreach.continue:
    mov edx, [ebp + cont.map.length]
    cmp edx, fixint_value(0)
    je .foreach.done
    call rn_force_transient_continuation
    jmp .next
  .foreach.done:
    mov ebp, [ebp + cont.parent]
    mov eax, inert_tag
    jmp [ebp + cont.program]
