;;;
;;; vectors.asm
;;;
;;; Vector manipulation applicatives.
;;;
;;; Layout of vector object:
;;;
;;; [vector_header(n), X0, X1, ..., Xn, unbound_tag], if n = 2k
;;; [vector_header(n+1), X0, X1, ..., Xn],            if n = 2k + 1
;;;

;;
;; rn_vector_length (native procedure)
;;
;; Compute length of a vector as tagged fixint.
;;
;; preconditions:  EBX = vector
;; postconditions: EAX = length as tagged fixint
;; preserves:      EBX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, ECX, EFLAGS
;;
rn_vector_length:
    mov eax, [ebx]
  .header:
    shr eax, 6                      ; EAX := tagged fixint
    lea eax, [eax - 3]              ;          (object length - 1)
    mov ecx, dword [ebx + eax - 1]  ; ECX := last field of the object
    cmp ecx, unbound_tag
    jne .done
    lea eax, [eax - 4]              ; subtract 1 from tagged fixint
  .done:
    ret

;;
;; app_vector_length (native procedure)
;;
;; Implementation of (vector-length VECTOR).
;;
;; preconditions:  EBX = VECTOR
;;                 EBP = current continuation
;;
app_vector_length:
  .A1:
    instrumentation_point
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, vector_header(0)
    jne .type_error
    shr eax, 6                      ; EAX := tagged fixint
    lea eax, [eax - 3]              ;          (object length - 1)
    mov ecx, dword [ebx + eax - 1]  ; ECX := last field of the object
    cmp ecx, unbound_tag
    jne .done
    lea eax, [eax - 4]              ; subtract 1 from tagged fixint
  .done:
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_vector_length)
    jmp rn_error

;;
;; aux_vector_access (native procedure)
;;
;; Check vector index.
;;
;; preconditions:  EBX = object
;;                 ECX = index (tagged fixint)
;;                 EDI = symbol for error reporting
;;
;; postconditions: return if the object is a vector
;;                        and the index is valid
;;                 jump to rn_error, if the object is not a vector
;;                                   or the index is not valid
;;
;; preserves:      EBX, ECX, ESI, EDI, EBP
;; clobbers:       EAX, EDX
;;
aux_vector_access:
    test bl, 3                ; is it a vector?
    jnz .type_error
    mov eax, [ebx]
    cmp al, vector_header(0)
    jne .type_error
    mov edx, ecx              ; EDX := index
    xor dl, 1                 ; is the index nonnegative fixint?
    test edx, 0x80000001
    jnz .invalid_index
    shr eax, 6                ; EAX = 4 * M, where M = object size
    lea eax, [eax - 7]        ; EAX = tagged (M - 2)
    cmp ecx, eax
    je .last_word
    ja .invalid_index
  .valid:
    ret
  .last_word:
    mov eax, [ebx + ecx + 3]
    cmp eax, unbound_tag
    jne .valid
  .invalid_index:
    mov eax, err_index_out_of_bounds
    mov ebx, ecx
    mov ecx, edi
    jmp rn_error
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, edi
    jmp rn_error

;;
;; app_vector_ref (native procedure)
;;
;; Implementation of (vector-ref VECTOR INDEX).
;;
;; preconditions:  EBX = vector
;;                 ECX = index
;;                 EBP = current continuation
;;
app_vector_ref:
  .A2:
    instrumentation_point
    mov edi, symbol_value(rom_string_vector_ref)
    call aux_vector_access
    mov eax, [ebx + ecx + 3]
    jmp [ebp + cont.program]

;;
;; app_vector_setB (native procedure)
;;
;; Implementation of (vector-set VECTOR INDEX VALUE).
;;
;; preconditions:  EBX = vector
;;                 ECX = index
;;                 EDX = value
;;                 EBP = current continuation
;;
app_vector_setB:
  .A3:
    instrumentation_point
    mov esi, edx
    mov edi, symbol_value(rom_string_vector_setB)
    call aux_vector_access
    mov [ebx + ecx + 3], esi
    mov eax, inert_tag
    jmp [ebp + cont.program]

;;
;; app_make_vector (native procedure)
;;
;; Implementation of (make-vector N [FILL]).
;;
;; preconditions:  EBX = N = requested vector length
;;                 ECX = fill value
;;                 EBP = current continuation
;;
app_make_vector:
  .A1:
    instrumentation_point
    mov ecx, inert_tag
  .A2:
    instrumentation_point
    mov edx, ecx                    ; EDX := fill value
    mov ecx, ebx                    ; ECX := tagged N
    xor cl, 1                       ; ECX := untagged 4 * N
    test ecx, 0x80000001            ;        (if valid)
    jnz .type_error
    shr ecx, 2                      ; ECX := untagged N
    lea ecx, [ecx + 2]              ; ECX := untagged (N + 2)
    and ecx, ~1                     ; ECX := M = 2*ceil((N+1)/2)
    call rn_allocate
    mov esi, eax                    ; ESI := new object
    shl ecx, 8
    mov cl, vector_header(0)        ; ECX := vector_header(M)
    mov [esi + vector.header], ecx  ; store header field
    mov [esi + ebx + 3], dword unbound_tag
    lea edi, [esi + 4]              ; address of element
    mov ecx, ebx
    shr ecx, 2                      ; ECX := untagged N
    mov eax, edx                    ; EAX := fill value
    rep stosd
    mov eax, esi                    ; EAX := new vector
    xor edi, edi
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_make_vector)
    jmp rn_error

