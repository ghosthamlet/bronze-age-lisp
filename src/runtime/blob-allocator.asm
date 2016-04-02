;;;
;;; blob-allocator.asm
;;;
;;; Allocation of blobs (strings, symbols, keywords, bytevectors).
;;;
;;; Needs macros from blob-data.asm.
;;;

;;
;; init_blob_heap (native procedure)
;;
;; Initialize blob heap descriptors and free list.
;;
;; preconditions:  none
;; postconditions: [first_blob] = [free_blob] = start of "ram" descriptors
;;                 all "ram" descriptors linked in free list
;;                 free list terminated by zero
;; preserves:      EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EFLAGS
;; stack usage:    1 dword (incl. call/ret)
;;
init_blob_heap:
    ;; get pointer to string heap
    mov eax, blob_heap_base
    ;;
    mov ecx, 1 + (blob_descriptors.ram - blob_descriptors) / 8
    lea ebx, blob_address(ecx)
    mov [free_blob], ecx
    mov [first_blob], ecx
    mov [ebx], eax
    add eax, configured_blob_heap_size
  .next_free_element:
    inc ecx
    mov [ebx + 4], ecx
    mov [ebx + 8], eax
    lea ebx, [ebx + 8]
    cmp ebx, (blob_descriptors.limit - 8)
    jne .next_free_element
    mov [ebx + 4], dword 0
    rn_trace configured_debug_gc_blobs, 'init-blobs', hex, [first_blob], hex, [free_blob]
    ret

;;
;; rn_allocate_blob (native procedure)
;;
;; preconditions:  ECX = length of blob in bytes
;;                 initialized blob heap
;; postconditions: EAX = the newly allocated blob
;;                       tagged as bytevector
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    12 dwords (incl. call/ret)
;;
rn_allocate_blob:
    push ebx
    push edx
    mov eax, [free_blob]
    mov ebx, blob_next(eax)
    test ebx, ebx
    jz .full
    mov edx, blob_address(eax)
    add edx, ecx
    jc .fail
    cmp edx, blob_address(ebx)
    jae .full
  .available:
    mov blob_address(ebx), edx
    mov [free_blob], ebx
    pop edx
    pop ebx
    shl eax, 8
    mov al, bytevector_tag
    rn_trace configured_debug_gc_blobs, 'new', hex, eax
    ret
  .full:
    call bl_collect
  .check:
    mov eax, [free_blob]
    mov ebx, blob_next(eax)
    test ebx, ebx
    jz .fail
    mov edx, blob_address(eax)
    add edx, ecx
    cmp edx, blob_address(ebx)
    jb .available
  .fail:
    pop edx
    pop ebx
    mov eax, err_out_of_blob_memory
    jmp rn_out_of_memory

rn_shrink_last_blob:
    ;; pre:  ecx = new size
    ;;       ebx = string or bytevector
    push eax
    push ebx
    push ecx
    push edx
    shr ebx, 8
    mov eax, blob_next(ebx)
    and eax, 0x00FFFFFF
    mov edx, [free_blob]
    cmp eax, edx
    jne .no
    mov eax, blob_address(edx)
    sub eax, blob_address(ebx)
    cmp eax, ecx
    jb .no
    add ecx, blob_address(ebx)
    mov blob_address(edx), ecx
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
  .no:
    pop edx
    pop ecx
    pop ebx
    pop eax
    mov eax, err_invalid_blob_heap_operation
    jmp rn_error
