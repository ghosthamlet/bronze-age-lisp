;;;
;;; object-names.asm
;;;
;;; Guessing name from an object.
;;;

;;
;; rn_guess_name (native procedure)
;;
;; preconditions:  EBX = object
;;
;; postconditions: EAX = symbol or #inert
;;                 EBX = object associated with the name
;;
;; preserves:      ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX, EFLAGS
;;
rn_guess_name:
    call rn_guess_builtin_name
    cmp al, symbol_tag
    je .done
    test bl, 3
    jnz .done
    mov eax, [ebx]
    cmp bl, applicative_header(0)
    jne .failed
    mov ebx, [ebx + applicative.underlying]
    jmp rn_guess_name
  .failed:
    mov eax, inert_tag
  .done:
    ret

rn_guess_builtin_name:
    xor eax, eax
  .next:
    cmp [ground_private_lookup_table + 4 * eax], ebx
    je .found
    inc eax
    cmp eax, ground_lookup_table_length
    jb .next
  .not_found:
    mov eax, inert_tag
    ret
  .found:
    inc eax
    shl eax, 8
    mov al, symbol_tag
    ret
