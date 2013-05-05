;;;
;;; lisp-allocator.asm
;;;
;;; Allocator for lisp values.
;;;

%define enable_allocator_checks 1 ;(configured_debug_gc_cycle || configured_debug_gc_detail || configured_debug_evaluator)

;;
;; init_lisp_heap (native procedure)
;;
;; Initialize lisp heap at program startup.
;;
;; preconditions:  none
;; postconditions: [lisp_heap_pointer] = heap free pointer
;;                 [transient_pointer]
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EFLAGS
;; stack usage:    2 dword (incl. call/ret)
;;
init_lisp_heap:
    push eax
    mov eax, lisp_heap_area
    add eax, (2*configured_lisp_heap_size - 1)   ; align
    and eax, ~(2*configured_lisp_heap_size - 1)  ; ...
    add eax, configured_lisp_transient_size      ; reserve transient space
    mov [transient_limit], eax
    mov [lisp_heap_pointer], eax
    rn_trace configured_debug_gc_cycle, 'init_lisp_heap', hex, eax
    pop eax
    ret

;;
;; rn_allocate (native procedure)
;;
;; Allocates block on the lisp heap.
;;
;; Collects garbage if necessary. Pointers to all objects
;; which shall survie must be
;;
;;   - saved in one of the registers EBX, EDX, ESI, EDI, EBP
;;   - saved on the native stack
;;   - referenced by private environment object
;;
;; preconditions:         ECX = block size in 32-bit words (untagged)
;;                        0 < ECX < heap size / 8
;;                        ECX is a multiple of 2
;;
;; postconditions:        EAX = points to the new block
;;
;; preserves value:       ECX
;; preserves as GC roots: EBX, EDX, ESI, EBP
;; clobbers:              EAX, EFLAGS
;; stack usage:           12 dwords (incl. call/ret)
;;
rn_allocate:
    test ecx, 1 | ~((configured_lisp_heap_size >> 3) - 1)
    jnz .wrong_size
    push edi
    mov edi, [lisp_heap_pointer]
    lea eax, [edi + ecx*4 + configured_lisp_heap_threshold]      ; pointer past new object
    xor eax, edi
    test eax, 3 | ~(configured_lisp_heap_size - 1)  ; outside fromspace?
    jnz .heap_full
  .memory_available:
    mov eax, edi                    ; new object
%if enable_allocator_checks
    test eax, 7
    jnz .check_failed_1
%endif
    lea edi, [edi + ecx*4]          ; new free pointer
    mov [lisp_heap_pointer], edi
%if enable_allocator_checks
    test edi, 7
    jnz .check_failed_2
%endif
    pop edi
    ret
%if enable_allocator_checks
  .check_failed_1:
    mov eax, err_internal_error
    mov ebx, fixint_value(0xA110C01)
    mov ecx, inert_tag
    jmp rn_fatal
  .check_failed_2:
    mov eax, err_internal_error
    mov ebx, fixint_value(0xA110C02)
    mov ecx, inert_tag
    jmp rn_fatal
%endif
  .heap_full:
    push ebx         ; save registers as roots
    push ecx
    push edx
    push esi
    push ebp
    call gc_collect  ; estabilish new heap and move live objects there
    pop ebp          ; restore registers
    pop esi
    pop edx
    pop ecx
    pop ebx
    lea eax, [edi + ecx*4 + configured_lisp_heap_threshold]      ; pointer past new object
    xor eax, edi
    test eax, 3 | ~(configured_lisp_heap_size - 1)  ; outside fromspace?
    jz .memory_available
    mov eax, err_out_of_lisp_memory
    jmp rn_out_of_memory
  .wrong_size:
    mov eax, err_internal_error
    lea ebx, [ecx * 4 + 1]
    mov ecx, inert_tag
    jmp rn_out_of_memory

;;
;; rn_cons (native procedure)
;;
;; Allocate mutable pair.
;;
;; preconditions:  [ESP + 8] = car value
;;                 [ESP + 4] = cdr value
;;                 [ESP]     = return address
;;
;; postconditions: EAX = new mutable pair value
;;                 ESP' = ESP + 12
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP, ESP (call/ret)
;; clobbers:       EAX, EFLAGS
;;
;; example of usage: push CAR
;;                   push CDR
;;                   call rn_cons
;;                   mov PAIR, eax
;;

rn_cons:
    push ecx
    mov ecx, 2
    call rn_allocate
%if enable_allocator_checks
    test eax, 7
    jnz .check_failed
%endif
    mov ecx, [esp + 12]
    mov [eax], ecx
    mov ecx, [esp + 8]
    mov [eax + 4], ecx
    load_mutable_pair eax, eax
    pop ecx
    ret 8
%if enable_allocator_checks
  .check_failed:
    mov eax, err_internal_error
    mov ebx, fixint_value(0xC048)
    mov ecx, inert_tag
    jmp rn_fatal
%endif
;;
;; rn_allocate_transient (native procedure)
;;
;; Allocates transient block on the lisp heap.
;;
;; Collects garbage if necessary. Pointers to all objects
;; which shall survie must be
;;
;;   - saved in one of the registers EBX, EDX, ESI, EDI, EBP
;;   - saved on the native stack
;;   - referenced by private environment object
;;
;; preconditions:         ECX = negated block size in 32-bit words (untagged)
;;                        ECX < 0
;;
;; postconditions:        EAX = points to the new block
;;
;; preserves value:       ECX
;; preserves as GC roots: EBX, EDX, ESI, EDI, EBP
;; clobbers:              EAX
;; stack usage:           11 dwords (incl. call/ret)
;;
rn_allocate_transient:
    push ebx
    mov  ebx, ecx
    xor  ebx, 0xFFFFFF00
    test ebx, 0xFFFFFF01
    jnz  .wrong_size
    call rn_transient_min
  .redo:
    lea eax, [eax + 4*ecx]
    mov ebx, eax
    xor ebx, [lisp_heap_pointer]
    test ebx, 3 | ~(configured_lisp_heap_size - 1)
    jnz .transient_area_full
    pop ebx
    ret
  .transient_area_full:
    rn_trace configured_debug_gc_detail, 'transient-full', hex, eax, hex, ecx
    push ecx         ; save registers as roots
    push edx
    push esi
    push edi
    push ebp
    call gc_collect  ; estabilish new heap and move live objects there
    pop ebp          ; restore current cont. for error handling
    mov edi, [lisp_heap_pointer]
    lea eax, [edi + configured_lisp_transient_size + configured_lisp_heap_threshold]      ; pointer past new object
    xor eax, edi
    test eax, 3 | ~(configured_lisp_heap_size - 1)  ; outside fromspace?
    jnz .heap_full
    pop edi          ; restore registers
    pop esi
    pop edx
    pop ecx
    mov eax, [transient_limit]
    rn_trace configured_debug_gc_detail, 'transient-collected', hex, eax
    jmp .redo        ; try again
  .wrong_size:
    mov eax, err_internal_error
    lea ebx, [ecx * 4 + 1]
    mov ecx, inert_tag
    jmp rn_error
  .heap_full:
    mov eax, err_out_of_lisp_memory
    jmp rn_out_of_memory

;;
;; rn_transient_min (native procedure)
;;
;; Computes the transient area free pointer.
;;
;; preconditions:  EBP, EDI
;;
;; postconditions: EAX = transient area minimal live pointer
;; preserves:      ECX, EDX, ESI, EDI, EBP
;; stack usage:    1 (incl. call/ret)
;;
rn_transient_min:
    mov eax, [transient_limit]
    mov ebx, [lisp_heap_pointer]
    and ebx, ~(configured_lisp_heap_size - 1)
    test ebp, 3
    jnz .L1
    cmp ebx, ebp
    ja .L1
    cmp eax, ebp
    jb .L1
    mov eax, ebp
  .L1:
    ;; eax = min(max(ebp, heap_base), transient_limit)
    test edi, 3
    jnz .L2
    cmp ebx, edi
    ja .L2
    cmp eax, edi
    jb .L2
    mov eax, edi
  .L2:
    ;; eax = min(max(edi, heap_base), max(ebp, heap_base), transient_limit)
    ;rn_trace configured_debug_gc_detail, 'transient_min', hex, eax, hex, ebp, hex, edi, hex, [transient_limit]
    ret

;;
;; rn_capture (native procedure)
;;
;; Capture transient pointer.
;;
;; preconditions:  EAX = lisp value
;;
;; postconditions: if EAX is a pointer to transient continuation
;;                 or environment object, the object is made
;;                 persistent by adjusting [transient_limit]
;;
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP (call/ret)
;; clobbers:       EFLAGS
;;
rn_capture:
    push ebx
    test al, 3
    jnz .done
    mov ebx, [lisp_heap_pointer]
    and ebx, ~(configured_lisp_heap_size - 1)
    cmp eax, ebx
    jb .done
    cmp eax, [transient_limit]
    jae .done
    mov [transient_limit], eax
  .done:
    pop ebx
    ret

;;
;; shallow_copy (native procedure)
;;
;; Makes a copy of lisp object with header on the lisp heap.
;; Collects garbage if necessary (see allocate).
;;
;; preconditions:         EBX = object
;; postconditions:        EAX = the copy
;; preserves as GC roots: EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:              EAX, EFLAGS
;; stack usage:           ??? TODO ??? dwords (incl. call/ret)
;;
rn_shallow_copy:
    push ecx
    push esi
    push edi
    mov ecx, [ebx]
    shr ecx, 8
    call rn_allocate
    mov esi, ebx
    mov edi, eax
    rep movsd
    pop edi
    pop esi
    pop ecx
    ret

;;
;; shallow_transient_copy (native procedure)
;;
;; Makes a transient copy of lisp object on the lisp heap.
;; Collects garbage if necessary (see allocate).
;;
;; preconditions:         EBX = object
;; postconditions:        EAX = the copy
;; preserves as GC roots: EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:              EAX
;; stack usage:           15 dwords (incl. call/ret)
;;
rn_shallow_transient_copy:
    push ecx
    push esi
    mov ecx, [ebx]
    shr ecx, 8
    neg ecx
    call rn_allocate_transient
    neg ecx
    push edi
    mov esi, ebx
    mov edi, eax
    rep movsd
    pop edi
    pop esi
    pop ecx
    ret
