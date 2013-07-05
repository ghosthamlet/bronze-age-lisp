;;;
;;; bytevectors.asm
;;;
;;; Bytevector features.
;;;

rn_nonnegative_fixint_procz:
    call rn_fixintP_procz
    jne .fail
    cmp ebx, fixint_value(0)
    jl .fail
    test al, 0                 ; ZF := 1
    ret
  .fail:
    test ebx, ebx              ; ZF := 0
    ret

;;
;; app_bytevector_length (continuation passing procedure)
;;
;; Return length of a bytevector.
;;
;; preconditions: EBX = bytevector
;;                EBP = current continuation
;;
app_bytevector_length:
  .A1:
    cmp bl, bytevector_tag
    jne .error
    call rn_get_blob_data
    lea eax, [4 * ecx + 1]
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_bytevector_length)
    jmp rn_error

;;
;; app_make_bytevector (continuation passing procedures)
;;
;; Allocate new bytevector.
;;
;; preconditions: EBX = length
;;                ECX = fill byte (for .A2 only)
;;                EBP = current continuation
;;
app_make_bytevector:
  .A1:
    mov ecx, fixint_value(0)
  .A2:
    call rn_nonnegative_fixint_procz ; LENGTH must be fixint >= 0
    jne .error
    xchg ebx, ecx                    ; EBX = FILL, ECX = LENGTH
    call rn_u8P_procz                ; FILL must fit a byte
    jne .error
    shr ecx, 2                       ; untag LENGTH
    call rn_allocate_blob            ; EAX := blob
    mov esi, eax                     ; ESI := blob
    xchg ebx, eax                    ; EBX := blob, EAX = FILL (tagged)
    shr eax, 2                       ; untag
    call rn_get_blob_data            ; ECX := blob length (untagged)
    mov edi, ebx                     ; EDI := blob data
    rep stosb
    mov eax, esi                     ; EAX := blob
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_make_bytevector)
    jmp rn_error

;;
;; app_bytevector_u8_ref (continuation passing procedure)
;;
;; Return element of a bytevector.
;;
;; preconditions: EBX = bytevector
;;                ECX = INDEX (tagged fixint)
;;                EBP = current continuation
;;
app_bytevector_u8_ref:
  .A2:
    xchg ebx, ecx
    call rn_nonnegative_fixint_procz ; INDEX must be fixint >= 0
    jne .type_error
    mov eax, ebx
    shr eax, 2                       ; EAX := untagged INDEX
    mov ebx, ecx
    cmp bl, bytevector_tag
    jne .type_error
    call rn_get_blob_data            ; EBX = address, ECX = length
    cmp eax, ecx                     ; check INDEX against length
    jge .index_error
    movzx eax, byte [ebx + eax]      ; read element
    lea eax, [4 * eax + 1]           ; tag as fixint
    jmp [ebp + cont.program]
  .index_error:
    lea ebx, [4 * eax + 1]           ; tag index
    mov eax, err_index_out_of_bounds
    mov ecx, symbol_value(rom_string_bytevector_u8_ref)
    jmp rn_error
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_bytevector_u8_ref)
    jmp rn_error

;;
;; app_bytevector_u8_setB (continuation passing procedure)
;;
;; Mutate element of a bytevector.
;;
;; preconditions: EBX = bytevector
;;                ECX = INDEX (tagged fixint)
;;                EDX = new ELEMENT (tagged fixint)
;;                EBP = current continuation
;;
app_bytevector_u8_setB:
  .A3:
    xchg ebx, edx                    ; EBX = ELEMENT, EDX = BLOB
    call rn_u8P_procz
    jne .type_error
    xchg ebx, ecx                    ; ECX = ELEMENT, EBX = INDEX
    call rn_nonnegative_fixint_procz ; INDEX must be fixint >= 0
    jne .type_error
    mov eax, ebx
    shr eax, 2                       ; EAX := untagged INDEX
    mov ebx, edx                     ; EBX := BLOB
    shr ecx, 2
    mov edx, ecx                     ; EDX := untagged ELEMENT                      
    cmp bl, bytevector_tag
    jne .type_error
    call rn_get_blob_data            ; EBX = address, ECX = length
    cmp eax, ecx                     ; check INDEX against length
    jge .index_error
    mov [ebx + eax], dl              ; write element
    mov eax, inert_tag               ; return #inert
    jmp [ebp + cont.program]
  .index_error:
    lea ebx, [4 * eax + 1]           ; tag index
    mov eax, err_index_out_of_bounds
    mov ecx, symbol_value(rom_string_bytevector_u8_setB)
    jmp rn_error
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_bytevector_u8_setB)
    jmp rn_error
