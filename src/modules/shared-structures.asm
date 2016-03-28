;;;
;;; shared-structures.asm
;;;
;;; Helper applicatives for management of structures
;;; with cycles and sharing.
;;;

;;
;; app_shared_structure_indicator (continuation passing procedure)
;;
;; Implements (shared-structure-indicator START), which
;; returns an applicative (boolean predicate) B?, such
;; that (B? X) returns true, iff the structural in-degree
;; of X with respect to START (defined below) is greater
;; than 1.
;;
;; An object X references object Y (and user program can
;; follow the reference) if
;;
;;  - X is a pair and Y is the car field or cdr field of X
;;  - X is error object and Y is the error message or irritant list
;;  - X is vector and Y is one of its elements
;;
;; An object X is reachable from START-OBJECT, if there exists
;; finite sequence START-OBJECT = X(0), X(1), ..., X(n+1) = X,
;; such that X(k) references X(k+1) for k = 0,1,...,n.
;; The structural indegree of Y is the number of pairwise
;; distinct (in the sense of eq?) Xs which are reachable
;; from START-OBJECT and reference Y.
;;
;; The applicative shared-structure-indicator facilitates
;; implementation of SRFI-38 compatible (write ...).
;;
app_shared_structure_indicator:
  .A1:
    instrumentation_point
    push ebp
    mov ebp, nil_tag
    call sh_explore
    mov ebx, ebp
    pop ebp
    call sh_package
    mov ebx, eax
    mov edx, sh_find.empty.A1
    cmp [ebx + operative.program], dword sh_find.empty.operate
    je .wrap
    mov edx, sh_find.nonempty.A1
  .wrap:
    mov ecx, 6
    call rn_allocate
    mov [eax + applicative.header], dword applicative_header(6)
    mov [eax + applicative.program], dword rn_asm_applicative.L11
    mov [eax + applicative.underlying], ebx
    mov [eax + applicative.var0], edx
    mov [eax + applicative.var1], dword inert_tag
    mov [eax + applicative.var2], dword inert_tag
    jmp [ebp + cont.program]

;;
;; sh_visit (native procedure)
;;
;; Set mark bit and mark values when visiting an object:
;;
;;  a) on 1st visit, mark bit = 0
;;     => set mark bit = 1 and mark value = 0
;;
;;  b) on 2nd visit, mark bit = 1 and mark value = 0
;;     => add object into a list linked through mark value
;;
;;  c) on k-th visit, k >= 3
;;     => do nothing
;;
;; preconditions:  EAX = mark index
;;                 EBX = object (whose mark index is in EAX)
;;                 ESI = base of array of mark bits
;;                 EDI = base of array of 32-bit mark values
;;                 EBP = head of list of objects, linked
;;                       through the 32-bit mark values
;;
;; postconditions: ZF = 1 for 1st visit
;;                 ZF = 0 for 2nd, 3rd, ... visit
;;                 EBP = head of possibly updated list
;;
;; preserves:      EAX, EBX, ESI, EDI
;; clobbers:       ECX, EDX, EBP, EFLAGS
;; stack usage:    1 (incl. call/ret)
;;
sh_visit:
    mov ecx, eax
    mov edx, eax
    shr ecx, 5                ; index of 32-bit word of mark bits
    and edx, 31               ; index of bit within the word
    bts [esi + 4 * ecx], edx  ; copy mark bit to CF and set it to 1
    jnc .first_visit          ; mark bit not set => visited the 1st time
    mov ecx, [edi + 4 * eax]  ; check mark value
    test ecx, ecx
    jz .second_visit          ; mark value zero => visited the second time
    ret                       ; ZF is not set here
  .first_visit:
    xor ecx, ecx              ; also set ZF = 1
    mov [edi + 4 * eax], ecx  ; set mark value to zero
    ret
  .second_visit:
    mov [edi + 4 * eax], ebp  ; add to pseudo linked list
    mov ebp, ebx              ; update list head
    xor cl, 1                 ; clear ZF
    ret

;;
;; sh_explore (native procedure)
;;
;; preconditions:  EBX = starting object
;;                 EBP = nil_tag
;;
;; postconditions: ESI = base of array of mark bits
;;                 EDI = base of array of 32-bit mark values
;;                 EBP = head of list of objects
;;
;; preserves:      no registers except ESP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EBP, EFLAGS
;;
sh_explore:
    call rn_clear_mark_bits
    call rn_mark_base_32
    mov edi, esi              ; EDI = base of 32-bit mark values
    call rn_mark_base_1       ; ESI = base of 1-bit marks
  .explore:
    test bl, 3
    jz .header
    jp .pair
    ret
  .header:
    mov eax, [ebx]
    cmp al, vector_header(0)
    je .vector
    cmp al, (error_header & 0xFF)
    je .error_object
    ret
  .pair:
    call rn_mark_index.pair
    call sh_visit
    jnz .skip
    push dword cdr(ebx)
    mov ebx, car(ebx)
    call .explore
    pop ebx
    jmp .explore
  .skip:
    ret
  .error_object:
    call rn_mark_index.header
    call sh_visit
    jnz .skip
    push dword [ebx + error.irritants]
    mov ebx, [ebx + error.message]
    call .explore
    pop ebx
    jmp .explore
  .vector:
    call rn_mark_index.header
    call sh_visit
    jnz .skip
    mov ecx, [ebx]
    shr ecx, 8
    dec ecx
    jecxz .skip
  .next_vector_element:
    push ebx
    push ecx
    mov ebx, [ebx + 4*ecx]
    call .explore
    pop ecx
    pop ebx
    loop .next_vector_element
    ret

;;
;; sh_package (native procedure)
;;
;; preconditions:  EBX = head of list of objects
;;                 EDI = base of array of 32-bit mark values
;;
;; postconditions: EAX = operative closure
;;                 EBX = 0
;;                 ECX = 0
;;                 EDX = 0
;;                 ESI = 0
;;                 EDI = 0
;;
;; preserves:      EBP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
;;
sh_package:
    cmp ebx, nil_tag
    je .empty
    mov ecx, esp
  .next:
    push ebx
    call rn_mark_index
    mov ebx, [edi + 4 * eax]
    cmp ebx, nil_tag
    jne .next
  .done:
    sub ecx, esp
    shr ecx, 2
    test cl, 1
    jz .even
    push dword unbound_tag
    inc ecx
  .even:
    xor ebx, ebx   ; destroy pointers in unused halfspace
    xor esi, esi   ; of the heap, in case rn_allocate trigger
    xor edi, edi   ; garbage collection
    mov edx, ecx
    add ecx, 2
    call rn_allocate
    shl ecx, 8
    mov cl, operative_header(0)
    mov [eax + operative.header], ecx
    mov [eax + operative.program], dword sh_find.nonempty.operate
    mov ecx, edx
    mov esi, esp
    lea edi, [eax + operative.var0]
    lea esp, [esp + 4*ecx]
    rep movsd
  .clobber:
    xor ebx, ebx   ; destroy pointers which
    xor ecx, ecx   ; are not valid for the GC
    xor edx, edx
    xor esi, esi
    xor edi, edi
    ret
  .empty:
    mov ecx, 2
    call rn_allocate
    mov dword [eax + operative.header], operative_header(2)
    mov [eax + operative.program], dword sh_find.empty.operate
    jmp .clobber

sh_find:
  .nonempty.A1:
    mov eax, ebx
  .scan:
    mov ecx, [esi + operative.header]
    shr ecx, 8
    sub ecx, 2
    lea edi, [esi + operative.var0]
    repne scasd
    mov eax, boolean_value(0)
    setz ah
    xor edi, edi                      ; delete invalid pointer
    jmp [ebp + cont.program]
  .nonempty.operate:
    test bl, 3
    jz .error
    jnp .error
    mov ecx, cdr(ebx)
    cmp ecx, nil_tag
    jne .error
    mov eax, car(ebx)
    jmp .scan
  .error:
    mov eax, err_invalid_argument_structure
    mov ecx, inert_tag
    jmp rn_error
  .empty.operate:
    test bl, 3
    jz .error
    jnp .error
    mov ecx, cdr(ebx)
    cmp ecx, nil_tag
    jne .error
  .empty.A1:
    mov eax, boolean_value(0)
    jmp [ebp + cont.program]
