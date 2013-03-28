;;;
;;; continuation-ancestry.asm
;;;
;;; Ancestor-descendant relationship in first-class continuations.
;;;

;; layout of root continuation object
;;   .header
;;   .code = cont_root
;;   .parent = #inert
;; layout of error continuation object
;;   .header
;;   .code = cont_root
;;   .parent = root-continuation

%macro define_ancestor_cycle_subroutine 1
    mov %1, [%1 + cont.parent]
    cmp %1, inert_tag
    je %%encycle
    ret
  %%encycle:
    mov %1, eax
    ret
%endmacro

;;
;; rn_common_ancestor (native procedure)
;;
;; Finds common ancestor continuation with the smallest
;; dynamic extent.
;;
;; preconditions:  EAX = continuation object A
;;                 EBX = continuation object B
;; postconditions: EAX = EBX = least common ancestor of A and B
;; preserves:      ECX, EDX, ESI, EDI, EBP
;; stack usage:    5 dwords (incl. call/ret)
;;
;; Example:
;;
;;               R    R is the root continuation
;;              /     X, Y, C, W, R are ancestors of A
;;             W      Z, C, W, R are ancestors of B
;;            /       C, W, R are the common ancestors
;;           C
;;          / \       {A,B,C,X,Y,Z} is the dynamic extent of C
;;         Y   Z      {A,B,C,W,X,Y,Z} is the dynamic extent of W
;;        /     \     {A,B,C,R,W,X,Y,Z} is the dynamic extent of R
;;       X       B
;;      /             C is the common ancestor with the smallest
;;     A              dynamic extent
;;
;; Algorithm:
;;
;;   Each continuation C, which is ancestor of at least one
;;   of the the continuations A and B, is considered to
;;   be an element of a cyclic list, which starts at B,
;;   goes over the common ancestors to the root-continuation,
;;   and is artificialy encycled to A.
;;
;;   In the example above, the list is
;;
;;     (B Z . #1=(C W R A X Y . #1#))
;;
;;   Brent algorithm is applied, similarly to list-metrics.asm.
;;

rn_common_ancestor:
    push ecx
    push edx
    push esi
    push ebx
    mov edx, 1
  .L1:
    mov esi, ebx
    mov ecx, edx
  .L2:
    call .get_parent_ebx
    cmp ebx, esi
    je .found
    loop .L2
    shl edx, 1
    jmp .L1
  .found:
    sub edx, ecx
    inc edx
    mov ecx, edx
    pop ebx
    mov esi, ebx
  .L3:
    call .get_parent_esi
    loop .L3
    mov ecx, edx
    cmp ebx, esi
    jz .end
  .L4:
    inc edx
    call .get_parent_ebx
    call .get_parent_esi
    cmp ebx, esi
    jne .L4
  .end:
    mov eax, ebx
    pop esi
    pop edx
    pop ecx
    ret
  .get_parent_ebx:
    define_ancestor_cycle_subroutine ebx
  .get_parent_esi:
    define_ancestor_cycle_subroutine esi

;;
;; rn_descendantP_procz (native procedure)
;;
;; Decides relationship of two continuations.
;;
;; preconditions:  EAX = continuation object A
;;                 EBX = continuation object B
;; postconditions: ZF = 1 if A = B or A is descendant of B
;;                 ZF = 0 otherwise
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP, ESP (call/ret)
;; clobbers:       EAX
;; stack usage:    1 dword (incl. call/ret)
;;
rn_descendantP_procz:
    ;; Follow parent links from A, until either B is found,
    ;; or the root continuation is reached.
  .next_ancestor:
    cmp eax, ebx
    je .done
    mov eax, [eax + cont.parent]
    test al, 3
    jz .next_ancestor
  .done:
    ret
