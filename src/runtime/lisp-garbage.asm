;;;
;;; lisp-garbage.asm
;;;
;;; Garbage collector of lisp values.
;;;

%define enable_gc_checks 1

;;
;; gc_copy_loop REG (macro)
;;
;; Walk through array of values starting at EBP, until EBP
;; hits the register REG. The register REG may change value
;; during the loop.
;;
;; preconditions:  EBP = root array start
;;                 REG = root array end
;;                 ESI = any pointer to FROMSPACE
;;                 EDI = free pointer of TOSPACE
;;
;; postconditions: EBP = REG
;;                 EDI = free pointer of TOSPACE
;;                 all pointers in root array point to TOSPACE
;;
;; preserves:      EDX, ESP
;; clobbers:       EAX, EBX, ECX, ESI, EDI (alloc), EBP, EFLAGS
;; stack usage:    1 dword
;;

%macro gc_copy_loop 1
    jmp .L
  .header:
    xor eax, esi
    test eax, ~(configured_lisp_heap_size - 1)
    jnz .scan_loop
    call gc_evacuate_header
  .scan_loop:
    lea ebp, [ebp + 4]
  .L:
    cmp ebp, %1
    jge .scan_done
    mov eax, [ebp]
    test al, 3
    jz .header
    jnp .scan_loop
  .pair:
    lea ebx, car(eax)
    mov ecx, ebx
    xor ecx, esi
    test ecx, ~(configured_lisp_heap_size - 1)
    jnz .scan_loop
    call gc_evacuate_pair
    jmp .scan_loop
.scan_done:
%endmacro

;;
;; gc_copy_roots (native procedure)
;;
;; preconditions:  EBP = root array start
;;                 EDX = root array end
;;                 ESI = pointer to FROMSPACE
;;                 EDI = free pointer of TOSPACE
;;
;; postconditions: EBP = EDX
;;                 EDI = free pointer of TOSPACE
;;                 all pointers in root array point to TOSPACE
;;
;; preserves:      EDX, ESP
;; clobbers:       EAX, EBX, ECX, ESI, EDI (alloc), EBP
;; stack usage:    2 dwords (incl. call/ret)
;;
gc_copy_roots:
    rn_trace configured_debug_gc_detail, 'gc-roots', hex, ebp, hex, edx, hex, esi, hex, edi
    gc_copy_loop edx
    ret

;;
;; gc_copy_objects (native procedure)
;;
;; preconditions:  EBP = start of TOSPACE
;;                 ESI = pointer to FROMSPACE
;;                 EDI = free pointer of TOSPACE
;;
;; postconditions: EBP = EDI = free pointer of TOSPACE
;;                 all pointers in TOSPACE point to TOSPACE
;;                 TOSPACE is valid lisp heap
;;
;; preserves:      EDX, ESP (call/ret)
;; clobbers:       EAX, EBX, ECX, ESI, EDI (alloc), EBP
;; stack usage:    2 dwords (incl. call/ret)
;;
gc_copy_objects:
    rn_trace configured_debug_gc_detail, 'gc-objects', hex, ebp, hex, 0, hex, esi, hex, edi
    gc_copy_loop edi
    ret

;;
;; gc_evacuate_pair (native procedure)
;;
;; preconditions:  EBP = pointer to a slot. The slot must contain
;;                       pair value which points to FROMSPACE
;;                 EAX = pair value = [EBP]
;;                 EBX = address of CAR field
;;                 EDI = free pointer of TOSPACE
;;
;; postconditions: ESI = pointer somewhere in FROMSPACE (!)
;;                 EDI = new free pointer of TOSPACE
;;
;; preserves:      EDX, EBP
;; clobbers:       EAX, EBX, ECX, ESI, EDI, EFLAGS
;; stack usage:    1 dword (incl. call/ret)
;;
gc_evacuate_pair:
    mov  ecx, [ebx]      ; get CAR field
    xor  ecx, 0x40000003 ; regular lisp value
    test ecx, 0x40000003 ;   ...
    jz .forward          ;   or forwarding pair pointer?
    rn_trace configured_debug_gc_detail, 'e/pair', hex, ebx, hex, edi, hex, ebp, hex, [ebp]
    mov ecx, edi         ; get free pointer and tag it
    shr ecx, 1           ; as pair with the same mutability flag
    and eax, 0x80000003  ;   ...
    or eax, ecx          ;   ...
    mov [ebp], eax       ; store new tagged pair pointer
    mov esi, ebx         ; get pointer to CAR field
    movsd                ; copy CAR field
    movsd                ; copy CDR field
    or eax, 0x40000000   ; mark new value as forwarding pointer
    mov [ebx], eax       ; overwrite old CAR field with forwarding pointer
    ret
  .forward:
    mov ecx, [ebx]       ; get marked forwarding pointer
    and ecx, ~0x40000000 ; remove forwarding mark
    mov [ebp], ecx       ; copy forwarded value to the slot
    rn_trace configured_debug_gc_detail, 'f/pair', hex, ebx, hex, eax, hex, ecx
    ret

;;
;; gc_evacuate_header (native procedure)
;;
;; preconditions:  EBP = pointer to a slot. The slot must contain
;;                       a pointer to object with header in
;;                       FROMSPACE.
;;                 EDI = free pointer of TOSPACE
;;
;; postconditions: ESI = pointer somewhere in FROMSPACE (!)
;;                 EDI = free pointer of TOSPACE
;;
;; preserves:      EDX, EBP
;; clobbers:       EBX, ECX, ESI
;; stack usage:    1 dword (incl. call/ret)
;;
gc_evacuate_header:
    mov ebx, [ebp]      ; ebx = value (also a pointer)
    mov ecx, [ebx]      ; ecx = header word
    test cl, 3          ; is it object header (lsb = 01)
    jz .forward         ;    or forwarding pointer (lsb = 00)?
    rn_trace configured_debug_gc_detail, 'e/hdr', hex, ebx, hex, edi, hex, ebp, hex, [ebp], hex, ecx
    mov [ebp], edi      ; store pointer to the copy in the slot
    mov [ebx], edi      ; overwrite header with forwarding pointer
    mov [edi], ecx      ; copy header word
    lea esi, [ebx + 4]  ; pointer to the body of the original object
    lea edi, [edi + 4]  ; pointer to the body of the copy
%if enable_gc_checks
    test ecx, ((~(configured_lisp_heap_size/8 - 1) | 1) << 8) | 2
    jnz .bad
%endif
    shr ecx, 8          ; extract object size (in DWORDs)
    dec ecx             ; account for the header
    rep movsd           ; copy object body into TOSPACE
    ret
  .forward:
    rn_trace configured_debug_gc_detail, 'f/hdr', hex, ebx, hex, ecx, hex, ebp
    mov [ebp], ecx      ; copy forwarding pointer to the slot
    ret
%if enable_gc_checks
  .bad:
    mov eax, [edi - 4]
    rn_trace 1, 'BADGC/H', hex, eax, hex, ecx
    mov [ebx], eax
    rn_trace 1, 'BADGC/L', lisp, ebx, lisp, ebx
    ret
%endif

;;
;; gc_collect (native procedure)
;;
;; Collect lisp garbage. Registers which contain GC roots
;; must be saved in the native stack or private environment
;; object.
;;
;; preconditions:  all roots saved in lisp stack or private
;;                 environment object
;;
;; postconditions: EDI = free pointer of new TOSPACE
;;               - all live lisp objects moved to TOSPACE
;;               - transient environment area is empty
;;
;; preserves:      nothing (except ESP)
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EBP, EFLAGS
;; stack usage:    5 dwords (incl. call/ret)
;;
gc_collect:
    perf_time begin, lisp_gc
    mov esi, [lisp_heap_pointer]
    call gc_get_tospace
    push edi
    mov ebp, esp
    mov edx, [stack_limit]
    call gc_copy_roots
    mov ebp, ground_private_lookup_table
    lea edx, [ebp + 4 * private_lookup_table_length]
    call gc_copy_roots
    pop ebp
    call gc_copy_objects
    mov [lisp_heap_pointer], edi
    perf_time end, lisp_gc
%if configured_debug_gc_cycle
    mov eax, [lisp_heap_pointer]
    sub eax, [transient_limit]
    mov ebx, configured_lisp_heap_size
    sub ebx, eax
    rn_trace 1, 'used/free/transient', hex, eax, hex, ebx, hex, configured_lisp_transient_size
    push edi
    mov edi, [lisp_heap_pointer]
    and edi, ~(configured_lisp_heap_size - 1)
    xor edi, configured_lisp_heap_size
    mov ecx, configured_lisp_heap_size / 4
    mov eax, 0xDED0 | (0xDED0 << 2) | 1
    rep stosd
    pop edi
%endif
    ret

;;
;; gc_get_tospace (native procedure)
;;
;; Switch halfspaces of the copying collector.
;;
;; preconditions:  ESI = pointer to current TOSPACE
;; postconditions: EDI = free pointer in new TOSPACE
;; preserves:      EAX, EBX, ECX, EDX, ESI, EBP
;; clobbers:       EDI
;; stack usage:    1 dword (incl. call/ret)
;;
gc_get_tospace:
    mov edi, esi
    and edi, ~(configured_lisp_heap_size - 1)
    rn_trace configured_debug_gc_detail, 'gc-fromspace', hex, edi
    xor edi, configured_lisp_heap_size
    add edi, configured_lisp_transient_size
    rn_trace configured_debug_gc_detail, 'gc---tospace', hex, edi
    mov [transient_limit], edi
    ret
