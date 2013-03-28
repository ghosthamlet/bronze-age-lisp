
rn_blob_to_blobz:
    ;; pre: ebx = blob
    ;; post: eax = new blob
    push ecx
    push ebx
    call rn_get_blob_data
    inc ecx
    call rn_allocate_blob
    dec ecx
    xchg ebx, eax
    call rn_copy_blob_data
    mov eax, ebx
    call rn_get_blob_data
    mov [ebx + ecx - 1], byte 0
    pop ebx
    pop ecx
    ret

rn_stringz_to_blob:
    ;; pre: ebx = pointer
    ;; post: eax = new blob
    push ecx
    push edi
    xor eax, eax
    mov edi, ebx
    mov ecx, 0xFFFFFFFF
    repne scasb
    sub edi, ebx
    lea ecx, [edi - 1]
    call rn_allocate_blob
    xchg eax, ebx
    call rn_copy_blob_data
    xchg eax, ebx
    pop edi
    pop ecx
    ret
