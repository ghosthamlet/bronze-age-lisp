;;;
;;; equality.asm
;;;
;;; Equality predicates.
;;;

;;
;; rn_eq (native procedure)
;;
;; Compare two lisp values with the semantics of (eq? ...).
;;
;; preconditions:  EBX, ECX = values to compare
;;
;; postconditions: EAX = 1 if equal
;;                 EAX = 0 if not equal
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    1 dword (including call/ret)
;;
rn_eq:
    cmp ebx, ecx
    je .equal
    test bl, 3
    jz .header
  .not_equal:
    xor eax, eax
    ret
  .equal:
    mov eax, 1
    ret
  .header:
    test cl, 3
    jnz .not_equal
    jmp rn_eq_header

rn_eq_header:
    push ebx
    push ecx
    push edx
  .compare:
    mov eax, [ebx] ; get header fields
    mov edx, [ecx]
    cmp al, applicative_header(0)
    jne .not_equal
    cmp dl, applicative_header(0)
    jne .not_equal
  .applicative:
    mov ebx, [ebx + applicative.underlying]
    mov ecx, [ecx + applicative.underlying]
    cmp ebx, ecx
    je .equal
    test bl, 3
    jnz .not_equal
    test cl, 3
    jnz .not_equal
    jmp .compare
  .not_equal:
    xor eax, eax
    pop edx
    pop ecx
    pop ebx
    ret
  .equal:
    mov eax, 1
    pop edx
    pop ecx
    pop ebx
    ret

;;
;; rn_equal (native procedure)
;;
;; Compare two lisp values with the semantics of (equal? ...).
;;
;; preconditions:  EBX, ECX = values to compare
;;
;; postconditions: EAX = 1 if equal
;;                 EAX = 0 if not equal
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;;
;; The algorithm is based on implementation of (equal? ...)
;; in klisp.
;;

rn_equal:
    push ebx                          ; save registers
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebp, esp                      ; save stack pointer
    call rn_mark_base_32
    mov edx, esi
    add esi, 5 * all_mark_slots       ; esi = base of 1-bit marks
    mov edi, esi                      ; clear all 1-bit marks
    mov ecx, all_mark_slots / (8 * 4) ;   ...
    xor eax, eax                      ;   ...
    rep stosd                         ;   ...
    mov edi, edx                      ; edi = base of 32-bit marks
    mov ecx, [esp + 16]               ; restore ecx
    jmp .L2

  .equal:
    mov eax, 1
  .done:
    mov esp, ebp                      ; restore stack pointer
    pop ebp                           ; restore register
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
  .L1:
    cmp ebp, esp        ; is the stack empty?
    je .equal
    pop ebx             ; load next pair of values to compare
    pop ecx
  .L2:
    cmp ebx, ecx        ; identical representation?
    je  .L1
    cmp bl, string_tag  ; is the first value a string?
    je .string
    test bl, 3
    jz .header          ; is the first value an object with header?
    jp .pair            ; is the first value a pair?
  .not_equal:           ; if not (eq? ...), then not (equal? ...)
    xor eax, eax
    jmp .done

  .pair:
    test cl, 3
    jz .not_equal            ; if the second value is not a pair,
    jnp .not_equal           ;   then the values cannot be equal
    push ebx                 ; save both values
    push ecx
    call rn_mark_index.pair  ; get index for union-find
    mov ebx, ecx
    mov edx, eax
    call rn_equal_find       ; get root of the equivalence class
    mov ecx, eax
    call rn_mark_index.pair
    mov edx, eax
    call rn_equal_find
    mov ebx, eax
    cmp ebx, ecx             ; already "known" by transitivity?
    jz .skip_equality_check
    call rn_equal_merge      ; merge the equivalence classes
    pop ecx                  ; restore lisp values
    pop ebx
    push dword cdr(ebx)      ; push CDR fields on the stack
    push dword cdr(ecx)
    mov ebx, car(ebx)        ; CAR fields will be compared next
    mov ecx, car(ecx)
    jmp .L2

  .skip_equality_check:
    add esp, 8
    jmp .L1

  .header:
    mov eax, [ebx] ; get header fields
    mov edx, [ecx]
    cmp al, applicative_header(0)
    je .applicative
    cmp eax, edx
    jne .not_equal
    cmp al, vector_header(0)
    jne .not_equal
  .vector:
    jmp .error
  .applicative:
    cmp dl, applicative_header(0)
    jne .not_equal
    mov ebx, [ebx + applicative.underlying]
    mov ecx, [ecx + applicative.underlying]
    jmp .L2

  .string:
    cmp cl, string_tag
    jne .not_equal
    mov eax, ecx
    call rn_compare_blob_data
    jne .not_equal
    jmp .L1

  .error:
    mov eax, err_not_implemented
    mov esp, ebp
    pop ebp
    jmp rn_error

;;
;; rn_equal_find (native procedure)
;;
;; Find operation on the union-find structure.
;;
;; preconditions:  EDX = index of element
;;                 EDI = result of mark_base_32
;;                 ESI = result of mark_base_1
;;
;; postconditions: EAX = index of root element
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    2 dword (incl. call/ret)
;;
rn_equal_find:
    push edx
    mov eax, edx
    shr eax, 5                         ; index of 32-bit word
    and edx, 31                        ; index of bit within the word
    bts [esi + 4*eax], edx             ; get&set mark bit
    jc .already_initialized
    pop edx                            ; restore element index
    mov eax, edx                       ; return value
    mov mark_word_8(edi, edx), 0       ; rank := 0
    mov mark_word_32(edi, edx), edx    ; parent := self
    ret
  .already_initialized:
    mov edx, [esp]                     ; restore element index
    mov eax, mark_word_32(edi, edx)    ; get parent
    cmp eax, edx                       ; is it root?
    jnz .follow
    pop edx
    ret
  .follow:
    mov edx, eax
    mov eax, mark_word_32(edi, edx)
    cmp eax, edx
    jnz .follow
    pop edx
    mov mark_word_32(edi, edx), eax    ; path compression
    ret

;;
;; rn_equal_merge (native procedure)
;;
;; Merge operation on the union-find structure.
;;
;; preconditions:  EBX = index of root of equivalence class B
;;                 ECX = index of root of equivalence class C
;;                 EDI = result of mark_base_32
;;
;; postconditions: EAX = index of root of equivalence class A,
;;                       where A is union of B and C
;;
;; preserves:      EBX, ECX, ESI, EDI, EBP
;; clobbers:       EAX, EDX, EFLAGS
;; stack usage:    1 (incl. call/ret)
;;
rn_equal_merge:
    mov al, mark_word_8(edi, ebx)    ; rank(B)
    mov dl, mark_word_8(edi, ecx)    ; rank(C)
    cmp al, dl
    je .same_rank
    jb .B_small_C_big
  .B_big_C_small:
    mov mark_word_32(edi, ecx), ebx   ; parent(C) := B
    mov eax, ebx                      ; result := B
    ret
  .B_small_C_big:
    mov mark_word_32(edi, ebx), ecx   ; parent(B) := C
    mov eax, ecx                      ; result := C
    ret
  .same_rank:
    mov mark_word_32(edi, ecx), ebx   ; parent(C) := B
    inc mark_word_8(edi, ebx)         ; increment rank(B)
    mov eax, ebx                      ; result := B
    ret
