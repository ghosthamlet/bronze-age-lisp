;;;
;;; list-construction.asm
;;;
;;; Operations on lists.
;;;

;;
;; rn_list_rev (native procedure)
;;
;; Append reversed list.
;;
;; preconditions:  EAX = input list
;;                 EBX = tail
;;                 EDX = pair count (tagged fixint),
;;                 EDX >= length of input list
;; postconditions: EAX = rest of input list
;;                 EBX = output list (mutable)
;; preserves:      ECX, EDX, ESI, EDI (heap allocation), EBP
;; clobbers:       EAX, EBX
;; stack usage:    4 (incl. call/ret)
;;
rn_list_rev:
    ;rn_trace 1, 'list-rev', lisp, eax, lisp, ebx, lisp, edx
    cmp edx, fixint_value(0)
    je .done
    push edx
    push esi
    mov esi, eax
  .next:
    push dword car(esi)
    push ebx
    call rn_cons
    mov esi, cdr(esi)
    mov ebx, eax
    lea edx, [edx - 4]
    cmp edx, fixint_value(0)
    jne .next
    mov eax, esi
    pop esi
    pop edx
  .done:
    ret

;;
;; rn_list_rev_build (native procedure)
;;
;; Build list according to list metrics.
;;
;; preconditions:  EAX = input list, reversed
;;                 ECX = cycle length (tagged fixint)
;;                 EDX = pair count (tagged fixint)
;;                 EDX >= max(ECX, length of input list)
;; postconditions: EAX = rest of input list
;;                 EBX = output list
;; preserves:      ECX, EDX, ESI, EDI (heap allocation), EBP
;; clobbers:       EAX, EBX
;; stack usage:    4 (incl. call/ret)
;;
rn_list_rev_build:
    ;rn_trace 1, 'list-rev-build', lisp, eax, lisp, ecx, lisp, edx
    push edx
    mov ebx, nil_tag
    cmp ecx, fixint_value(0)
    jz .pfx
    push esi
    push ecx
    mov esi, eax
    mov ebx, car(esi)
    mov esi, cdr(esi)
    neg ecx
    lea edx, [edx + ecx + 1]
    neg ecx
    push edx
    lea edx, [ecx - 4]
    push ebx
    push ebx
    call rn_cons
    push eax
    mov ebx, eax
    mov eax, esi
    call rn_list_rev
    pop ecx
    mov cdr(ecx), ebx
    pop edx
    pop ecx
    pop esi
  .pfx:
    call rn_list_rev
    pop edx
    ret
