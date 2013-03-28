;;;
;;; critbit.asm
;;;
;;; Crit-bit tree for symbol interning.
;;;

%define _debug_critbit 0

;;
;; cb_descend (native procedure)
;;
;; Descend in crit-bit tree.
;;
;; preconditions:  EBX = key (blob)
;;                 EDX = tree root
;; postconditions: EAX = element
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    2 (incl call/ret)
;;
cb_descend:
    push edx
  .recurse:
    test dl, 3
    jnz .notree
    mov eax, [edx],
    cmp al, (critbit_header & 0xFF)
    jnz .notree
    mov eax, [edx + critbit.index]
    shr eax, 2                      ;; untag
    call rn_blob_bit
    mov edx, [edx + critbit.child0 + 4*eax]
    jmp .recurse
  .notree:
    mov eax, edx
    pop edx
    ret

;;
;; cb_insert (native procedure)
;;
;; Destructively insert value in crit-bit tree.
;;
;; preconditions:  EBX = key (blob)
;;                 ESI + EDI - 1 = pointer to tree root value
;;
;; postconditions if key exists in the tree:
;;                 ZF = 1
;;                 EAX = matching value
;;                 ESI + EDI - 1 = pointer to tree root value
;;
;; postconditions if not:
;;                 ZF = 0
;;                 ESI + EDI - 1 = pointer where new value can be stored
;;
;; preserves:      EBX, ECX, EDX, EBP
;; clobbers:       EAX, ESI, EDI, EFLAGS
;;
cb_insert:
    push ecx
    push edx
    call .start
    pop edx
    pop ecx
    ret
  .empty:
    rn_trace _debug_critbit, 'empty', hex, ebx
    cmp dl, nil_tag - 1 ; ZF := 0
    ret
  .start:
    ;; ebx = key
    ;; esi = parent object
    ;; edi = field index in the parent slot (tagged integer)
    rn_trace _debug_critbit, 'insert-start', hex, ebx, hex, esi, hex, edi
    mov edx, [esi + edi - 1]    ; get root
    cmp dl, nil_tag             ; empty tree?
    je .empty
    test dl, 3                  ; singleton?
    jnz .singleton
    call cb_descend             ; find best match
    call rn_compare_blob_bits   ; compare
    jz .done                    ; already in tree
    setc al                     ; get critical bit vs. best match
    and eax, 0xFF               ; convert to tagged slot index of tree node
    lea eax, [critbit.child0 + 4*eax + 1]
    push eax                    ; save
  .walk:
    ;; ebx = key
    ;; ecx = index of critical bit of the key (untagged)
    ;; edx = node
    ;; esi = parent node
    ;; edi = index of slot in the parent node (tagged integer)
    rn_trace _debug_critbit, 'insert-walk', hex, edx, hex, esi, hex, edi
    mov eax, [edx + critbit.index]
    shr eax, 2                      ;; untag
    cmp eax, ecx
    ja .insert
    call rn_blob_bit
    mov esi, edx
    lea edi, [critbit.child0 + 4*eax + 1]
    mov edx, [esi + edi - 1]
    test dl, 3
    jnz .insert
    cmp [edx], dword critbit_header
    je .walk
  .insert:
    ;; ebx = key
    ;; ecx = index of critical bit (untagged)
    ;; edx = original subtree
    ;; esi = object containing the parent slot
    ;; edi = field index in the parent slot (tagged integer)
    ;; [esp] = field index of 'old' subtree in new node
    mov eax, [esp]
    rn_trace _debug_critbit, 'insert', hex, ebx, hex, ecx, hex, edx, hex, eax
    push ecx
    mov ecx, 4
    call rn_allocate
    rn_trace _debug_critbit, 'insert-new', hex, eax
    mov [esi + edi - 1], eax
    pop ecx
    mov [eax + critbit.header], dword critbit_header
    lea ecx, [4*ecx + 1]
    mov [eax + critbit.index], ecx
    mov esi, eax
    pop edi
    mov [esi + edi - 1], edx
    xor edi, 4 ; get index of 'new' and ZF = 0
  .done:
    ret
  .singleton:
    rn_trace _debug_critbit, 'singleton', hex, ebx
    ;; ebx = new key
    ;; edx = old key
    ;; esi = parent object
    ;; edi = field index in the parent slot (tagged integer)
    mov eax, edx
    call rn_compare_blob_bits   ; compare
    jz .done
    setc al                     ; get critical bit vs. best match
    and eax, 0xFF               ; convert to tagged slot index of tree node
    lea eax, [critbit.child0 + 4*eax + 1]
    push eax
    jmp .insert
