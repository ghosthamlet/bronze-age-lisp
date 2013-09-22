;;;
;;; parameter-trees.asm
;;;
;;; Parameter trees and pattern matching.
;;;

;;
;; rn_check_ptree (native procedure)
;;
;; Check validity of formal parameter tree object. Valid
;; formal parameter tree is (see Kernel Report section 4.9.1)
;; a symbol, a keyword (extension over KR), #ignore, nil, or
;; a pair, whose CAR and CDR fields contain valid ptrees. The
;; object structure must be acyclic, and no symbol can occur
;; more than once.
;;
;; preconditions:  EBX = parameter tree to be checked
;;
;; postconditions if ptree is valid:
;;                 EAX = 0x00000000
;;                 EBX = parameter tree
;;
;; postconditions if ptree is not valid:
;;                 EAX = error message (lisp string value)
;;                 EBX = irritant subtree
;;
;; preserves:      ECX, EDX, ESI, EDI, EBP
;;
;; clobbers:       EAX, EFLAGS
;;                 mark bits
;;
rn_check_ptree:
    push ecx
    push edx
    push esi
    push edi
    perf_time begin, check_ptree
    call rn_check_ptree_quick
    perf_time end, check_ptree, save_regs
    pop edi
    pop esi
    pop edx
    pop ecx
    ret

;;
;; rn_check_ptree_quick (native procedure)
;;
;; Fast algorithm using hashing. If a collision
;; occurs, switch to more general algorithm.
;;
;; pre- and postconditions like rn_check_ptree
;; preserves: EBP
;; clobbers:  EAX, EBX, ECX, EDX, ESI, EDI
;;
rn_check_ptree_quick:
    push ebx
    push ebp
    xor esi, esi
    xor edi, edi
    mov ebp, esp
    call .recurse
    pop ebp
    pop ebx
    xor eax, eax
    ret
  .recurse:
    test bl, 3
    jz .error.invalid_type
    jp .pair
    cmp bl, symbol_tag
    je .hash_test
    cmp bl, nil_tag
    je .ignore
    cmp bl, ignore_tag
    je .ignore
    cmp bl, keyword_tag
    jne .error.invalid_type
  .ignore:
    ret
  .pair:
    call .hash_test
    push dword car(ebx)
    mov ebx, cdr(ebx)
    call .recurse
    pop ebx
    jmp .recurse
  .error.invalid_type:
    mov eax, err_invalid_ptree
    mov esp, ebp
    pop ebp
    pop ebx
    ret
  .collision:
    mov esp, ebp
    pop ebp
    pop ebx
    jmp rn_check_ptree_full
  .hash_test:
    mov eax, 0x89ABCDEF
    mul ebx
    mov eax, edx
    shr eax, 27
    shr edx, 22
    and edx, 31
    xor ecx, ecx
    bts esi, eax
    setc cl
    bts edi, eax
    setc ch
    test cl, ch
    jnz .collision
    ret

;;
;; rn_check_ptree_full (native procedure)
;;
;; General algorithm using mark bits.
;;
;; pre- and postconditions like rn_check_ptree
;; preserves: EBP
;; clobbers:  EAX, EBX, ECX, EDX, ESI, EDI
;;
rn_check_ptree_full:
    push ebp
    mov ebp, esp            ; save stack pointer for early aborts
    call rn_mark_base_1     ; esi = base of 1-bit marks
    xor eax, eax                      ; clear
    mov edi, esi                      ;   all 1-bit marks
    mov ecx, all_mark_slots / (8 * 4) ;   in 32-bit steps
    rep stosd                         ;   ...
    push ebx
    call .recurse
    pop ebx                 ; restore original object
    xor eax, eax            ; return value 0
  .abort:
    mov esp, ebp            ; restore stack pointer
    pop ebp
    ret
  .error.repeated_symbol:
    mov eax, err_repeated_symbol
    jmp .abort
  .error.cycle:
    mov eax, err_cyclic_ptree
    jmp .abort
  .error.invalid_type:
    mov eax, err_invalid_ptree
    jmp .abort

  .recurse:
    test bl, 3
    jz .error.invalid_type
    jp .pair
    cmp bl, symbol_tag
    je .symbol
    cmp bl, nil_tag
    je .ignore
    cmp bl, ignore_tag
    je .ignore
    cmp bl, keyword_tag
    jne .error.invalid_type
  .ignore:
    ret
  .symbol:
    call rn_mark_index.blob
    call .set_mark
    jc .error.repeated_symbol
    ret
  .pair:
    call rn_mark_index.pair
    call .set_mark
    jc .error.cycle
    push ebx
    mov ebx, car(ebx)
    call .recurse
    mov ebx, [esp]
    mov ebx, cdr(ebx)
    call .recurse
    pop ebx
    call rn_mark_index.pair
  .clear_mark:
    mov edx, eax
    shr eax, 5              ; index of 32-bit word in the mark bit array
    and edx, 31             ; index of bit within the word
    btr [esi + 4*eax], edx  ; clear mark bit
    ret
  .set_mark:
    mov edx, eax
    shr eax, 5              ; index of 32-bit word
    and edx, 31             ; index of bit within the word
    bts [esi + 4*eax], edx  ; copy mark bit to CF and set it to 1
    ret

;;
;; rn_match_ptree_procz (native procedure)
;;
;; preconditions:  EBX = pattern (valid formal parameter tree)
;;                 EDX = object
;; postconditions: ZF = 1 if object matches the pattern
;;                 ZF = 0 if object does not match the pattern
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EFLAGS
;;
rn_match_ptree_procz:
    push eax
    push ebx
    push edx
    push ebp
    mov ebp, esp
    call .recurse
  .abort:
    mov esp, ebp
    pop ebp
    pop edx
    pop ebx
    pop eax
    ret
  .recurse:
    cmp bl, symbol_tag
    jz .trivial
    cmp bl, ignore_tag
    jz .trivial
    test bl, 3
    jz .other
    jp .pair
  .other:
    cmp ebx, edx
    ret
  .trivial:
    xor al, al  ; set ZF=1
    ret
  .pair:
    test dl, 3
    jz .nopair
    jnp .nopair
    push dword cdr(ebx)
    push dword cdr(edx)
    mov ebx, car(ebx)
    mov edx, car(edx)
    call .recurse
    jnz .abort
    pop edx
    pop ebx
    jmp .recurse
  .nopair:
    test bl, bl ; set ZF = 0
    jmp .abort

;;
;; rn_bind_ptree (native procedure)
;;
;; preconditions:  EBX = pattern (valid formal parameter tree)
;;                 EDX = object (matching the formal ptree)
;;                 EDI = mutable environment
;;                 object matches the pattern
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EFLAGS
;;
rn_bind_ptree:
    push eax
    push ebx
    push edx
    call .recurse
    pop edx
    pop ebx
    pop eax
    ret
  .recurse:
    rn_trace configured_debug_evaluator, 'bind_ptree', lisp, ebx, lisp, edx
    cmp bl, symbol_tag
    je .case.symbol
    test bl, 3
    jz .case.ignore
    jnp .case.ignore
  .case.pair:
    push dword cdr(ebx)
    push dword cdr(edx)
    mov ebx, car(ebx)
    mov edx, car(edx)
    call .recurse
    pop edx
    pop ebx
    jmp .recurse
  .case.ignore:
    ret
  .case.symbol:
    mov eax, ebx
    mov ebx, edx
    rn_trace configured_debug_evaluator, 'bind_symbol', lisp, eax, lisp, ebx
    jmp rn_mutate_environment
