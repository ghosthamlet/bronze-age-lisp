;;;
;;; mark-bits.asm
;;;
;;; Mark words and bits.
;;;
;;;

%define mark_word_32(base, index)   dword [(base) + 4 * (index)]
%define mark_word_8(base, index)    byte [(base) + 4 * (all_mark_slots) + (index)]

;; rn_mark_base_32, _8, _1 (native procedures)
;;
;; Compute base address of array of 32-bit mark words,
;; 8-bit mark bytes and mark bits, respectively. The
;; arrays are stored in the unused halfspace of the
;; copying garbage collector.
;;
;; preconditions:  valid [lisp_heap_pointer]
;; postconditions: ESI = base address
;; preserves:      EAX, EBX, ECX, EDX, EDI, EBP
;; clobbers:       ESI
;; stack usage:    2 dwords (incl. call/ret)
;;
rn_mark_base_32:
    mov esi, [lisp_heap_pointer]               ; heap pointer
    and esi, ~(configured_lisp_heap_size - 1)  ; heap base
    xor esi, configured_lisp_heap_size         ; unused halfspace
    ret

rn_mark_base_8:
    call rn_mark_base_32
    add esi, (4 * all_mark_slots)
    ret

rn_mark_base_1:
    call rn_mark_base_32
    add esi, (5 * all_mark_slots)
    ret

;;
;; rn_mark_index (native procedure)
;;
;; Compute index of lisp value. Each string, pair and object
;; with header (including objects stored in read-only data
;; section) gets unique index.
;;
;; preconditions:  EBX = value
;; postcondition:  EAX = index (0 ... all_mark_slots - 1)
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    2 dwords (incl. call/ret)
;;
rn_mark_index:
    test bl, 3
    jz .header
    jp .pair
    cmp bl, string_tag
    je .blob
    mov eax, all_mark_slots - 1
    ret
  .blob:
    mov eax, ebx
    shr eax, 8
    add eax, heap_mark_slots + rom_mark_slots
    ret
  .pair:
    push ebx
    lea ebx, car(ebx)
    call .header
    pop ebx
    ret
  .header:
    cmp ebx, lisp_rom_limit
    jb .rom
  .ram:
    mov eax, [lisp_heap_pointer]
    and eax, ~(configured_lisp_heap_size - 1)
    sub eax, ebx
    neg eax
    shr eax, 3
    ret
  .rom:
    mov eax, ebx
    sub eax, lisp_rom_base
    shr eax, 3
    add eax, heap_mark_slots
    ret

;;
;; rn_clear_mark_bits (native procedure)
;;
;; Clears all bits in the array returned by rn_mark_base_1
;;
;; preconditions:  [lisp_heap_pointer] valid
;; postcondition:  all mark bits zero
;; preserves:      EBX, EDX, EBP
;; clobbers:       EAX, ECX, ESI, EDI, EFLAGS
;; stack usage:    3 dwords (incl. call/ret)
;;
rn_clear_mark_bits:
    call rn_mark_base_1
    mov edi, esi
    mov ecx, all_mark_slots / (8 * 4)
    xor eax, eax
    rep stosd
    ret
