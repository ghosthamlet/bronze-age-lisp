;;;
;;; deep-copies.asm
;;;
;;; Deep copy of shared and cyclic structures.
;;;

;;
;; rn_copy_es_immutable (native procedure)
;;
;; Copy evaluation structure.
;;
;; preconditions: EBX = object to be copied
;; postcondition: EAX = clone
;;
;; preserves:     EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers       EAX, EFLAGS
;; stack usage:   O(#mutable pairs)
;; heap usage:    O(#mutable pairs)
;;
;; Algorithm:
;;   - Traverses the structure depth-first, following
;;     both CAR and CDR. Uses the native stack.
;;   - Mutates the original structure during traversal.
;;     Modifications are eventually undone. Information
;;     for undoing is maintained in heap-allocated chain
;;     of vectors.
;;   - When it encounters mutable pair:
;;     - allocates clone pair
;;     - mutates the original pair
;;     - allocates undo vector
;;     - descends to CAR and CDR
;;   - Does not copy immutable pairs and other structures.
;;
;; Takes advantage of the rule that immutable pairs does
;; not directly reference mutable pair.
;;
rn_copy_es_immutable:
    push ebx
    push ecx
    push esi
    xor esi, esi         ; zero denotes end of undo chain
    call .copy
    test esi, esi        ; undo chain empty?
    jz .done
    push eax
  .undo:
    mov eax, [esi + vector.element0]
    mov ebx, [esi + vector.element1]
    mov ecx, [esi + vector.element2]
    mov esi, [esi + vector.element3]
    mov car(eax), ebx
    mov cdr(eax), ecx
    test esi, esi
    jnz .undo
    pop eax
  .done:
    pop esi
    pop ecx
    pop ebx
    ret
  .copy:
    mov eax, ebx
    xor  eax, 0x80000003
    test eax, 0x80000003
    jz .mutable_pair
    mov eax, ebx
    ret
  .mutable_pair:
    mov eax, car(ebx)
    test eax, eax
    jz .marked_pair
    ;; allocate 8 words on the heap
    mov ecx, 8
    call rn_allocate
    ;; Initialize first 6 words as a vector:
    ;;
    ;; element [0] = original mutable cons cell
    ;;         [1] = original CAR
    ;;         [2] = original CDR
    ;;         [3] = pointer to previous undo vector
    ;;         [4] = #inert (padding)
    ;;
    mov [eax + vector.header], dword vector_header(6)
    mov [eax + vector.element0], ebx
    mov ecx, car(ebx)
    mov [eax + vector.element1], ecx
    mov ecx, cdr(ebx)
    mov [eax + vector.element2], ecx
    mov [eax + vector.element3], esi
    mov ecx, inert_tag
    mov [eax + vector.element4], ecx
    mov esi, eax
    ;; Initialize 2 words as a pair (#inert . #inert).
    ;; The pair becomes the clone.
    lea eax, [eax + 24]                ; pointer to last 2 words
    mov [eax], ecx                     ; CAR of clone
    mov [eax + 4], ecx                 ; CDR of clone
    shr eax, 1                         ; tag as
    or  al, 3                          ;   immutable pair
    ;; mark the original pair and store forwarding pointer
    ;; for future traversal
    mov car(ebx), dword 0              ; mark
    mov cdr(ebx), eax                  ; tagged pointer to clone
    ;; copy CAR and CDR recursively
    push eax                           ; push pointer to clone
    push dword [esi + vector.element2] ; push original CDR
    mov ebx, [esi + vector.element1]   ; get original CAR
    call .copy                         ;   copy it
    mov ecx, [esp + 4]                 ; get clone
    mov car(ecx), eax                  ;   and store copy of CAR
    pop ebx                            ; get original CDR
    call .copy                         ;   and copy it
    pop ecx                            ; get clone
    mov cdr(ecx), eax                  ;   and store copy of CDR
    mov eax, ecx                       ; return clone
    ret
  .marked_pair:
    mov eax, cdr(ebx)                  ; get clone
    ret
