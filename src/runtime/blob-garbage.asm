;;;
;;; blob-garbage.asm
;;;
;;; Garbage collector of blobs (strings, symbols, keywords, bytevectors)
;;;
;;; Needs macros from blob-data.asm.

;;
;; bl_mark (native procedure)
;;
;; preconditions:  EBX = array base
;;                 ECX = array length
;; postconditions: EBX = pointer past array end
;;                 ECX = 0
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX
;; stack usage:    1 dword (incl. call/ret)
;;
bl_mark:
    rn_trace configured_debug_gc_blobs, 'bl_mark', hex, ebx, hex, ecx
    jecxz .done
  .next:
    mov eax, [ebx]
    lea ebx, [ebx + 4]
    cmp eax, blob_value_bound
    jae .continue
    xor al, (symbol_tag & bytevector_tag)
    test al, ~(symbol_tag ^ bytevector_tag)
    jz .mark
  .continue:
    loop .next
  .done:
    ret
  .mark:
    rn_trace configured_debug_gc_blobs, 'mark', hex, eax
    shr eax, 8
    mov edx, blob_next(eax)
    or edx, blob_mark_bit
    mov blob_next(eax), edx
    loop .next
    ret

;;
;; bl_compact (native procedure)
;;
;; Compact blob heap.
;;
;; preconditions:  live blobs marked
;; postconditions: live blobs compacted
;;                 dead blob descriptors linked in free list
;; preserves:      nothing except ESP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI
;; stack usage:    1 dwords (incl. call/ret)
;;
bl_compact:
    mov ebx, [first_blob]
    xor edx, edx
    mov edi, blob_address(ebx)
    xor ebp, ebp
    rn_trace configured_debug_gc_blobs, 'bl_compact', hex, ebx, hex, edx, hex, edi
  .skip_dead:
    ;; ebx = next blob index to process
    ;; edx = index of head of free list descriptors
    ;; ebp = 0
    mov eax, ebx
    mov ebx, blob_next(eax)
    test ebx, ebx
    jz .compact_end
    js .live
    rn_trace configured_debug_gc_blobs, 'skip-dead', hex, eax
    mov blob_next(eax), edx    ; link in free list
    mov edx, eax               ; update free list head
    jmp .skip_dead
  .first_live:
    mov [first_blob], eax
    jmp .live
  .compact_next:
    ;; ebx = next blob index to process
    ;; edi = free space pointer
    ;; edx = index of head of free list descriptors
    ;; ebp = previous live blob
    mov eax, ebx
    mov ebx, blob_next(eax)
    test ebx, ebx
    jz .compact_end
    jns .dead
  .link_live:
    mov blob_next(ebp), eax
  .live:
    rn_trace configured_debug_gc_blobs, 'live', hex, eax, hex, ebp
    mov ebp, eax
    and ebx, 0x00FFFFFF
    mov esi, blob_address(eax)
    cmp edi, esi
    jb .move
    mov edi, blob_address(ebx)
    jmp .compact_next
  .move:
    mov ecx, blob_address(ebx)
    sub ecx, esi
    mov blob_address(eax), edi
    rn_trace configured_debug_gc_blobs, 'move', hex, eax, hex, esi, hex, edi, hex, ecx
    rep movsb
    jmp .compact_next
  .dead:
    rn_trace configured_debug_gc_blobs, 'dead', hex, eax
    mov blob_next(eax), edx    ; link in free list
    mov edx, eax               ; update free list head
    jmp .compact_next
  .compact_end:
    ;; eax = sentry
    ;; edx = regular free list
    mov esi, blob_address(eax) ; end of heap
    xchg edx, eax              ; edx = prev, eax = next
    rn_trace configured_debug_gc_blobs, 'end', hex, edx, hex, eax, hex, edi
    test eax, eax
    jz .reverse_end
  .reverse_free_list:
    rn_trace configured_debug_gc_blobs, 'free', hex, edx, hex, eax
    mov ebx, blob_next(eax)
    mov blob_address(eax), esi
    mov blob_next(eax), edx
    mov edx, eax
    mov eax, ebx
    test eax, eax
    jnz .reverse_free_list
    mov blob_address(edx), edi
  .reverse_end:
    test ebp, ebp
    jz .no_live_link
    rn_trace configured_debug_gc_blobs, 'L', hex, edx, hex, ebp
    mov blob_next(ebp), edx
    %if 1
    mov eax, blob_address(ebp)
    mov ebx, blob_address(edx)
    rn_trace configured_debug_gc_blobs, 'X', hex, eax, hex, ebx, hex, edi
    %endif
  .no_live_link:
    mov [free_blob], edx
    ret

;;
;; bl_collect (native procedure)
;;
;; Collect garbage on blob heap.
;;
;; preconditions:  live strings saved in stack, heap, registers
;;                 EBP, ESI valid, if used as roots
;;                 EDI = lisp heap free pointer
;;                 transient_limit, stack_limit valid
;;
;; postconditions: live blobs compacted
;;                 dead blob descriptors linked in free list
;;
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       none
;; stack usage:    9 dwords (incl. call/ret)
;;
bl_collect:
    ;; save registers on stack as roots
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push ebp
    perf_time begin, blob_gc
    rn_trace configured_debug_gc_blobs, 'bl_collect', hex, [first_blob], hex, [free_blob]
    ;; mark roots on stack
    mov ebx, esp
    mov ecx, [stack_limit]
    sub ecx, ebx
    shr ecx, 2
    call bl_mark
    ;; mark roots on lisp heap
    call rn_transient_min
    mov ebx, eax
    mov ecx, [lisp_heap_pointer]
    sub ecx, ebx
    shr ecx, 2
    call bl_mark
    ;; mark roots in persistent environment
    mov ebx, ground_private_lookup_table
    mov ecx, private_lookup_table_length
    call bl_mark
    ;; compact
    push edi
    call bl_compact
    pop edi
    ;;
    rn_trace configured_debug_gc_blobs, 'end', hex, [first_blob], hex, [free_blob]
    perf_time end, blob_gc
    ;; restore registers
    pop ebp
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
