;;;
;;; blob-data.asm
;;;
;;; Blob data manipulation.
;;;
;;;

%define blob_address(k) [blob_descriptors + 8*(k-1)]
%define blob_next(k) [blob_descriptors + 8*(k-1) + 4]
%define blob_value_bound ((1 + (blob_descriptors.limit - blob_descriptors)/8) << 8)

%define blob_mark_bit   0x80000000
%define blob_index_mask 0x00FFFFFF
%define blob_flag_mask  0xFF000000

%macro m_get_blob_data 3
    shr %1, 8                  ; untag
    mov %3, blob_next(%1)      ; index of next blob
    and %3, blob_index_mask    ; remove mark bits
    mov %3, blob_address(%3)   ; address of next blob
    mov %2, blob_address(%1)   ; address of this blob
    sub %3, %2                 ; compute length
%endmacro

;;
;; rn_get_blob_data (native procedure)
;;
;; Retrieve offset and length of blob contents.
;;
;; preconditions:  EBX = blob value (symbol, string, keyword, bytevector)
;; postconditions: EBX = pointer to blob data
;;                 ECX = length in bytes (untagged integer)
;; preserves:      EAX, EDX, ESI, EDI, EBP
;; clobbers:       EBX, ECX, EFLAGS
;; stack usage:    1 dword (incl. call/ret)
;;
rn_get_blob_data:
    m_get_blob_data ebx, ebx, ecx
    ret

;;
;; rn_copy_blob_data (native procedure)
;;
;; preconditions:  EAX = source (blob or raw pointer)
;;                 EBX = destination (blob or raw pointer)
;;                 ECX = byte count
;;                 ECX <= min. size of source and destination
;;                 DF = 0
;; postconditions: ECX = 0
;;                 data copied
;; preserves:      EAX, EBX, EDX, ESI, EDI, EBP
;; clobbers:       ECX, EFLAGS
;;
rn_copy_blob_data:
    push eax
    push ebx
    push esi
    push edi
    cmp eax, blob_value_bound
    jae .raw_source
    shr eax, 8
    mov eax, blob_address(eax)
  .raw_source:
    mov esi, eax
    cmp ebx, blob_value_bound
    jae .raw_destination
    shr ebx, 8
    mov ebx, blob_address(ebx)
  .raw_destination:
    mov edi, ebx
    rep movsb
    pop edi
    pop esi
    pop ebx
    pop eax
    ret

rn_compare_blob_data:
    ;; pre: eax = blob A (string, symbol, keyword, bytevector)
    ;;      ebx = blob B (string, symbol, keyword, bytevector)
    ;; post if A = B : ecx = 0, ZF = 1, SF = 0
    ;; post if A < B : ecx negative, ZF = 0, SF = 1
    ;; post if A > B : ecx positive, ZF = 0, SF = 0
    ;;
    ;; where "<" is some fixed order on blobs.
    ;;
    ;; preserve: eax, ebx, edx, esi, edi, ebp
    push eax
    push ebx
    push edx
    push esi
    push edi
    shr eax, 8
    shr ebx, 8
    mov esi, blob_address(eax)
    mov edx, blob_next(eax)
    and edx, blob_index_mask
    mov edx, blob_address(edx)
    sub edx, esi
    mov edi, blob_address(ebx)
    mov ecx, blob_next(ebx)
    and edx, blob_index_mask
    mov ecx, blob_address(ecx)
    sub ecx, edi
    sub edx, ecx
    jnz .length
    repe cmpsb
    jnz .contents
    xor ecx, ecx
    jmp .done
  .contents:
    movzx edx, byte [esi - 1]
    movzx ecx, byte [edi - 1]
    sub edx, ecx
  .length:
    mov ecx, edx
  .done:
    pop edi
    pop esi
    pop edx
    pop ebx
    pop eax
    ret
