;;;
;;; strings.asm
;;;
;;; String manipulation applicatives.
;;;

;;
;; app_string_size (continuation passing procedure)
;;
;; Implementation of (string-size STRING), which returns
;; size (measured in bytes) of UTF-8 representation of STRING.
;;
;; preconditions: EBX = STRING
;;                EBP = current continuation
;;
app_string_size:
  .A1:
    instrumentation_point
    cmp bl, string_tag
    jne .error
    call rn_get_blob_data
    lea eax, [4 * ecx + 1]
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_string_size)
    jmp rn_error

;;
;; app_string_length (continuation passing procedure)
;;
;; Implementation of (string-length STRING), which returns
;; length of STRING measured in characters.
;;
;; preconditions: EBX = STRING
;;                EBP = current continuation
;;
;; Algorithm:
;;   Count all bytes, except the continuation bytes of multibyte
;;   UTF-8 sequences. These bytes have the binary representation
;;   10xxxxxx, where x denotes arbitrary bit value.
;;
app_string_length:
  .A1:
    instrumentation_point
    cmp bl, string_tag
    jne .error
    call rn_get_blob_data
    xor edx, edx
    jecxz .done
  .next_byte:
    movzx eax, byte [ebx]
    inc ebx
    xor al, 0x80
    test al, 0xC0
    setnz al
    add edx, eax
    loop .next_byte
  .done:
    lea eax, [4*edx + 1]
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_string_length)
    jmp rn_error

;;
;; app_string_ref (continuation passing procedure)
;;
;; Implementation of (string-ref STRING K), which returns
;; Kth (zero-based index) character of STRING.
;;
;; preconditions: EBX = STRING
;;                ECX = K (tagged fixint)
;;                EBP = current continuation
;;
;; Algorithm: Skip K characters (see app_string_length)
;;            and decode the next one.
;;
app_string_ref:
  .A2:
    instrumentation_point
    mov esi, ebx             ; ESI := string
    mov edi, ecx             ; EDI := index (tagged fixint)
    cmp bl, string_tag
    jne .type_error
    mov ebx, ecx             ; EBX := index (for error message)
    mov eax, ecx
    xor al, 1
    test eax, 0x80000003
    jne .type_error
    mov ebx, esi
    call rn_get_blob_data    ; EBX := string data, ECX := string size
    shr edi, 2               ; untag index
    mov edx, -1              ; counter of passed characters := -1
    jecxz .overrun
  .scan:
    movzx eax, byte [ebx]
    inc ebx
    xor al, 0x80
    test al, 0xC0
    setnz al
    add edx, eax
    cmp edx, edi
    je .found
    loop .scan
  .overrun:
    mov eax, err_index_out_of_bounds
    lea ebx, [4 * edi + 1]
    mov ecx, symbol_value(rom_string_string_ref)
    jmp rn_error
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_string_ref)
    jmp rn_error
  .found:
    lea esi, [ebx - 1]       ; ESI := pointer to first byte of the character
    xor ebx, ebx             ; EBX = decoder DFA state := 0 = UTF8_ACCPET
    xor ecx, ecx             ; ECX = codepoint accumulator := 0
  .decode:
    movzx eax, byte [esi]
    inc esi
    call rn_decode_utf8
    test ebx, ebx            ; EBX ?= UTF8_ACCEPT?
    jnz .decode
    mov eax, ecx             ; tag codepoint as char
    shl eax, 8
    mov al, char_tag
    jmp [ebp + cont.program]

;;
;; app_string_append (continuation passing procedure)
;;
;; Implementation of (string-append . STRINGS).
;;
app_string_append:
  .A0:
    instrumentation_point
    mov eax, string_value(rom_empty_string)
    jmp [ebp + cont.program]
  .O1:
    mov ebx, car(esi)
  .A1:
    instrumentation_point
    cmp bl, string_tag
    jne .type_error
    mov eax, ebx
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    jmp .fail
  .structure_error:
    mov eax, err_invalid_argument_structure
    jmp .fail
  .overflow:
    mov eax, err_out_of_blob_memory
  .fail:
    mov ecx, symbol_value(rom_string_string_append)
    jmp rn_error
  .operate:
    mov esi, ebx           ; ESI := input list
    call rn_list_metrics   ; EDX := list length
    test eax, eax
    jz .structure_error
    test ecx, ecx
    jnz .structure_error
    cmp edx, 1
    jb .A0
    je .O1
    ;; sum
    push edx
    mov edi, esi           ; EDI := input list
    xor eax, eax           ; sum lengths in EAX
  .add_next:
    mov ebx, car(esi)
    mov esi, cdr(esi)
    cmp bl, string_tag
    jne .type_error
    call rn_get_blob_data
    add eax, ecx
    jo .overflow
    dec edx
    jnz .add_next
    mov esi, edi           ; ESI := input list
    pop edx                ; EDX := input list length
    mov ecx, eax           ; ECX := total length
    call rn_allocate_blob  ; EAX := new string (tagged)
    push eax
    mov ebx, eax
    call rn_get_blob_data
    mov edi, ebx           ; EDI := start of output string data
  .copy_next:
    mov ebx, car(esi)
    mov esi, cdr(esi)
    call rn_get_blob_data
    mov eax, ebx           ; EAX := input string
    mov ebx, edi           ; EBX := address in output string
    add edi, ecx           ; EDI := address for next string
    call rn_copy_blob_data
    dec edx
    jnz .copy_next
    xor edi, edi           ; discard non-heap pointers
    xor ebx, ebx           ;   ...
  .done:
    pop eax
    mov al, string_tag
    jmp [ebp + cont.program]
