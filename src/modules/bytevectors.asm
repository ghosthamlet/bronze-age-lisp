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
    instrumentation_point
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
    instrumentation_point
    mov ecx, fixint_value(0)
  .A2:
    instrumentation_point
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
    instrumentation_point
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
    instrumentation_point
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

;;
;; app_bytevector_copy (continuation passing procedure)
;;
;; Copy a bytevector.
;;
;; preconditions: EBX = source bytevector
;;                EBP = current continuation
;;
app_bytevector_copy:
  .A1:
    instrumentation_point
    cmp bl, bytevector_tag
    jne .error
    mov esi, ebx            ; ESI := source
    call rn_get_blob_data   ; EBX := base, ECX := length
    call rn_allocate_blob   ; EAX := new bytevector
    mov ebx, eax            ; EBX := new bytevector
    mov eax, esi            ; EAX := source
    call rn_copy_blob_data  ; copy data
    mov eax, ebx            ; EAX := new bytevector
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_bytevector_copy)
    jmp rn_error

;;
;; app_string_Gutf8 (continuation passing procedure)
;;
;; Copy a string and tag the result as bytevector.
;;
;; preconditions: EBX = source string
;;                EBP = current continuation
;;
app_string_Gutf8:
  .A1:
    instrumentation_point
    cmp bl, string_tag
    jne .error
    mov esi, ebx            ; ESI := source
    call rn_get_blob_data   ; EBX := base, ECX := length
    call rn_allocate_blob   ; EAX := new bytevector
    mov ebx, eax            ; EBX := new bytevector
    mov eax, esi            ; EAX := source
    call rn_copy_blob_data  ; copy data
    mov eax, ebx            ; EAX := new bytevector
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_string_Gutf8)
    jmp rn_error

;;
;; app_bytevector_copy_partial (continuation passing procedure)
;;
;; Copy bytes from a bytevector.
;;
;; preconditions: EBX = FROM byetevector
;;                ECX = START index
;;                EDX = END index
;;                EBP = current continuation
;;
app_bytevector_copy_partial:
  .A3:
    instrumentation_point
    mov edi, symbol_value(rom_string_bytevector_copy_partial)
    mov esi, ecx
    call bytevector_copy_partial_helpers.bytevector_arg
    push ebx
    push ecx
    mov ebx, esi
    call bytevector_copy_partial_helpers.untag_index_arg
    push ebx
    mov ebx, edx
    call bytevector_copy_partial_helpers.untag_index_arg
    push ebx
    ;; [ESP +  0] = END (untagged)
    ;; [ESP +  4] = START (untagged)
    ;; [ESP +  8] = FROM bytevector length (untagged)
    ;; [ESP + 12] = FROM bytevector base address
    mov eax, [esp + 4]       ; EAX := START
    mov ebx, [esp + 0]       ; EBX := END
    mov ecx, [esp + 8]       ; ECX := bytevector length
    call bytevector_copy_partial_helpers.check_range
    mov ecx, ebx             ; ECX := END
    sub ecx, eax             ; ECX := END - START
    call rn_allocate_blob
    mov ebx, eax             ; EBX := new blob
    mov eax, [esp + 12]      ; EAX := FROM bytevector base address
    add eax, [esp +  4]      ; EAX := FROM base + START
    call rn_copy_blob_data
    mov eax, ebx             ; EAX := new blob
    add esp, 16              ; clean up
    jmp [ebp + cont.program]   
    
;;
;; app_bytevector_copy_partialB (continuation passing procedure)
;;
;; Copy bytes between bytevectors.
;;
;; preconditions: EBX = parameter tree (FROM START END TO AT)
;;                EBP = current continuation
;;
app_bytevector_copy_partialB:
  .operate:
    call rn_list_metrics
    mov edi, symbol_value(rom_string_bytevector_copy_partialB)
    test eax, eax
    jz bytevector_copy_partial_helpers.structure_error
    test ecx, ecx
    jnz bytevector_copy_partial_helpers.structure_error
    cmp edx, 5
    jne bytevector_copy_partial_helpers.structure_error
    ;; copy arguments from the operand list to the stack
    mov esi, ebx
    mov ebx, car(esi)
    call bytevector_copy_partial_helpers.bytevector_arg
    mov esi, cdr(esi)
    push ebx
    push ecx
    mov ebx, car(esi)
    call bytevector_copy_partial_helpers.untag_index_arg
    mov esi, cdr(esi)
    push ebx
    mov ebx, car(esi)
    call bytevector_copy_partial_helpers.untag_index_arg
    mov esi, cdr(esi)
    push ebx
    mov ebx, car(esi)
    call bytevector_copy_partial_helpers.bytevector_arg
    mov esi, cdr(esi)
    push ebx
    push ecx
    mov ebx, car(esi)
    call bytevector_copy_partial_helpers.untag_index_arg
    push ebx
    ;; [ESP +  0] = AT (untagged)
    ;; [ESP +  4] = TO bytevector length (untagged)
    ;; [ESP +  8] = TO bytevector base address
    ;; [ESP + 12] = END (untagged)
    ;; [ESP + 16] = START (untagged)
    ;; [ESP + 20] = FROM bytevector length (untagged)
    ;; [ESP + 24] = FROM bytevector base address
    mov eax, [esp + 16]  ; EAX := START
    mov ebx, [esp + 12]  ; EBX := END
    mov ecx, [esp + 20]  ; ECX := FROM length
    call bytevector_copy_partial_helpers.check_range
    mov eax, [esp +  0]  ; EAX := AT
    mov ebx, [esp + 12]  ; EBX := END
    add ebx, eax         ; EBX := AT + END
    sub ebx, [esp + 16]  ; EBX := AT + END - START
    mov ecx, [esp +  4]  ; ECX := TO length
    call bytevector_copy_partial_helpers.check_range
  .copy:
    mov eax, [esp + 16]  ; EAX := START
    mov ecx, [esp + 12]  ; ECX := END
    sub ecx, eax         ; ECX := END - START
    jz .done
    mov esi, [esp + 24]  ; ESI := FROM base
    add esi, eax         ; ESI := FROM base + START
    mov edi, [esp +  8]  ; EDI := TO base
    add edi, [esp +  0]  ; EDI := TO base + AT
    cmp esi, edi
    je .done
    jb .copy_backward
  .copy_forward:
    rep movsb
    jmp .done
  .copy_backward:
    lea esi, [esi + ecx - 1]
    lea edi, [edi + ecx - 1]
    std
    rep movsb
    cld
  .done:
    add esp, 28
    mov eax, inert_tag
    jmp [ebp + cont.program]

bytevector_copy_partial_helpers:
  .check_range:
    cmp eax, ebx
    jnle .index_error
    cmp ebx, ecx
    jnle .index_error
    ret
  .untag_index_arg:
    mov eax, ebx
    xor eax, 1
    test eax, 0x80000003
    jne .type_error
    shr ebx, 2
    ret
  .bytevector_arg:
    cmp bl, bytevector_tag
    jne .type_error
    call rn_get_blob_data
    ret
  .structure_error:
    mov eax, err_invalid_argument_structure
    jmp .error
  .type_error:
    mov eax, err_invalid_argument
    mov ebx, car(esi)
    jmp .error
  .index_error:
    mov eax, err_index_out_of_bounds
    lea ebx, [4 * ebx + 1]
  .error:
    mov ecx, edi
    jmp rn_error
