;;;
;;; heap-images.asm
;;;
;;; Save and restore interpreter state.
;;;

struc saved_heap_header
  .ground_private_base resd 1
  .ground_private_size resd 1
  .lisp_heap_base resd 1
  .lisp_heap_size resd 1
  .blob_descriptors_base resd 1
  .blob_descriptors_size resd 1
  .blob_contents_base resd 1
  .blob_contents_size resd 1
  .first_blob resd 1
  .free_blob resd 1
  .current_continuation resd 1
endstruc

app_save_heap_aux:
  .A2:
    instrumentation_point
    ;; ebx = integer or port
    ;; ecx = value to be passed to the current continuation
    mov edi, ecx
    mov eax, [lisp_heap_pointer]
    mov esi, symbol_value(rom_string_save_heap_image)
    call app_dup2.get_fd
    mov esi, ebx
    ;; esi = file descriptor (tagged integer)
    ;; edi = return value
    ;; discard references to all heap-allocated values, except the current
    ;; continuation, and run the garbage collector
    mov eax, inert_tag
    mov ebx, eax
    mov ecx, eax
    mov edx, eax
    ;; [esp + 4] = the current continuation
    ;; [esp + 0] = open file descriptor
    call bl_collect
    mov eax, [lisp_heap_pointer]
    ;; make sure that the current halfspace is the lower one
    mov eax, [lisp_heap_pointer]
    xor eax, lisp_heap_area
    test eax, ~(configured_lisp_heap_size - 1)
    jz .make_header
    push ebp
    push esi
    push edi
    call gc_collect
    pop edi
    pop esi
    pop ebp
  .make_header:
    ;; build header in [scratchpad + ...]
    ;;   private environment
    mov eax, ground_private_lookup_table
    mov [scratchpad_start + saved_heap_header.ground_private_base], eax
    mov eax, 4 * private_lookup_table_length
    mov [scratchpad_start + saved_heap_header.ground_private_size], eax
    ;;   lisp heap
    mov eax, [lisp_heap_pointer]
    and eax, ~(configured_lisp_heap_size - 1)
    add eax, configured_lisp_transient_size
    mov [scratchpad_start + saved_heap_header.lisp_heap_base], eax
    mov ebx, [lisp_heap_pointer]
    sub ebx, eax
    mov [scratchpad_start + saved_heap_header.lisp_heap_size], ebx
    ;;   blob heap, descriptor table
    mov eax, blob_descriptors.ram
    mov [scratchpad_start + saved_heap_header.blob_descriptors_base], eax
    mov eax, blob_descriptors.limit
    sub eax, blob_descriptors.ram
    mov [scratchpad_start + saved_heap_header.blob_descriptors_size], eax
    ;;   blob heap, descriptor indices
    mov eax, [first_blob]
    mov [scratchpad_start + saved_heap_header.first_blob], eax
    mov eax, [free_blob]
    mov [scratchpad_start + saved_heap_header.free_blob], eax
    ;;   blob heap, contents
    mov ebx, blob_heap_base
    mov [scratchpad_start + saved_heap_header.blob_contents_base], ebx
    mov eax, blob_address(eax)
    sub eax, ebx
    mov [scratchpad_start + saved_heap_header.blob_contents_size], eax
    ;;   the current continuation (saved EBP)
    mov [scratchpad_start + saved_heap_header.current_continuation], ebp
    ;; write header and heap to the file
    mov ebx, esi         ; file descriptor (tagged integer)
    shr ebx, 2           ; untag
    mov ecx, scratchpad_start
    mov edx, saved_heap_header_size
    call .write
    mov ecx, [scratchpad_start + saved_heap_header.ground_private_base]
    mov edx, [scratchpad_start + saved_heap_header.ground_private_size]
    call .write
    mov ecx, [scratchpad_start + saved_heap_header.lisp_heap_base]
    mov edx, [scratchpad_start + saved_heap_header.lisp_heap_size]
    call .write
    mov ecx, [scratchpad_start + saved_heap_header.blob_descriptors_base]
    mov edx, [scratchpad_start + saved_heap_header.blob_descriptors_size]
    call .write
    mov ecx, [scratchpad_start + saved_heap_header.blob_contents_base]
    mov edx, [scratchpad_start + saved_heap_header.blob_contents_size]
    call .write
    ;; close the file descriptor
    mov eax, 6     ; close() system call
    call call_linux
    ;; return to lisp
    mov eax, edi
    mov ebx, inert_tag
    mov ecx, ebx
    mov edx, ebx
    mov esi, ebx
    mov edi, ebx
    jmp [ebp + cont.program]
  .write:
    ;; ebx = file descriptor (untagged)
    ;; ecx = buffer base
    ;; edx = buffer size
    push ebx
    push ecx
    push edx
    mov eax, 0x04   ; write() system call
    call call_linux 
    pop edx
    pop ecx
    pop ebx
    test eax, eax   ; check return code
    js .write_error
    add ecx, eax
    sub edx, eax
    jnz .write
    ret
  .write_error:
    mov esi, inert_tag
    cmp eax, -EINTR
    je .eintr
    jmp linux_write.error
  .eintr:
    ;; cannot handle EINTR here
    mov eax, err_internal_error
    mov ebx, esi
    mov ecx, esi
    jmp rn_fatal

app_restore_heap_aux:
  .A2:
    instrumentation_point
    ;; ebx = integer or port
    ;; ecx = value passed to the loaded continuation
    ;;       (must not be heap-allocated)
    mov edi, ecx ; save value
    mov esi, symbol_value(rom_string_save_heap_image)
    call app_dup2.get_fd
    shr ebx, 2   ; untag file descriptor
    mov ecx, scratchpad_start
    mov edx, saved_heap_header_size
    call .read
    mov ecx, [scratchpad_start + saved_heap_header.ground_private_base]
    mov edx, [scratchpad_start + saved_heap_header.ground_private_size]
    call .read
    mov ecx, [scratchpad_start + saved_heap_header.lisp_heap_base]
    mov edx, [scratchpad_start + saved_heap_header.lisp_heap_size]
    call .read
    mov ecx, [scratchpad_start + saved_heap_header.blob_descriptors_base]
    mov edx, [scratchpad_start + saved_heap_header.blob_descriptors_size]
    call .read
    mov ecx, [scratchpad_start + saved_heap_header.blob_contents_base]
    mov edx, [scratchpad_start + saved_heap_header.blob_contents_size]
    call .read
    ;; close the file descriptor
    mov eax, 6       ; close() system call
    call call_linux
    ;;
    ;; reinitialize global variables (see runtime/bss.asm)
    ;;
    ;;                       K = keep, R = reset, L = load from file
    ;;
    ;;   stack limit ................ K
    ;;   transient_limit              R
    ;;   lisp_heap_pointer            L
    ;;   first_blob                   L
    ;;   free_blob                    L
    ;;   rn_error_active              K (should be zero)
    ;;   backup_cc_*                  K (should not be in use)
    ;;   last_*                       R (TODO: not really used)
    ;;   platform_info                K (current syscal & environment info)
    ;;   sigring_*                    K (independent of lisp heap)
    ;;   perf_time_buffer             K (independent of lisp heap)
    ;;   signal_stack                 K (should not be in use)
    ;;   fuzzer data (if enabled) ... K (independent of lisp heap)
    ;;
    ;; reset transient_limit
    mov eax, lisp_heap_area + configured_lisp_transient_size
    mov [transient_limit], eax
    ;; restore lisp heap free pointer
    mov eax, [scratchpad_start + saved_heap_header.lisp_heap_base]
    add eax, [scratchpad_start + saved_heap_header.lisp_heap_size]
    mov [lisp_heap_pointer], eax
    ;; restore list of blobs
    mov eax, [scratchpad_start + saved_heap_header.first_blob]
    mov [first_blob], eax
    mov eax, [scratchpad_start + saved_heap_header.free_blob]
    mov [free_blob], eax
    ;; reset last_* variables
    xor eax, eax
    mov [last_combination], eax
    mov [last_combiner], eax
    mov [last_ptree], eax
    ;; restore the current continuation and invoke the loaded continuation
    mov ebp, [scratchpad_start + saved_heap_header.current_continuation]
    mov eax, edi
    mov ebx, inert_tag
    mov ecx, ecx
    mov edx, ecx
    mov esi, ecx
    mov edi, ecx
    jmp [ebp + cont.program]
  .read:
    ;; ebx = file descriptor (untagged)
    ;; ecx = buffer base
    ;; edx = buffer size
    push ebx
    push ecx
    push edx
    mov eax, 0x03   ; read() system call
    call call_linux 
    pop edx
    pop ecx
    pop ebx
    test eax, eax   ; check return code
    js .read_error
    add ecx, eax
    sub edx, eax
    jnz .read
    ret
  .read_error:
    ;; cannot handle any errors, the heap may not be completely loaded
    mov eax, err_internal_error
    mov ebx, inert_tag
    mov ecx, inert_tag
    jmp rn_fatal
