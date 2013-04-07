;;;
;;; encapsulations.asm
;;;
;;; Implementation of Kernel encapsulated types.
;;;
;;; Encapsulation class is a fresh pair (#inert . #inert).
;;;

app_make_encapsulation_type:
  .A0:
    ;; create class object
    mov eax, inert_tag
    push eax
    push eax
    call rn_cons
    mov edi, eax
    ;; create decapsulator applicative
    mov edx, app_decapsulate.A1
    call .pack_codec
    push eax
    push dword nil_tag
    call rn_cons
    mov ebx, eax
    ;; create predicate applicative
    call .pack_predicate
    push eax
    push ebx
    call rn_cons
    mov ebx, eax
    ;; create encapsulator applicative
    mov edx, app_encapsulate.A1
    call .pack_codec
    push eax
    push ebx
    call rn_cons
    jmp [ebp + cont.program]
  .pack_codec:
    mov ecx, 8
    call rn_allocate
    lea ecx, [eax + 16]
    mov [eax + applicative.header], dword applicative_header(4)
    mov [eax + applicative.program], dword rn_asm_applicative.L11
    mov [eax + applicative.underlying], ecx
    mov [eax + applicative.var0], edx
    mov [ecx + operative.header], dword operative_header(4)
    mov [ecx + operative.program], dword rn_asm_operative.L11
    mov [ecx + operative.var0], edx
    mov [ecx + operative.var1], edi
    ret
  .pack_predicate:
    mov ecx, 16
    call rn_allocate
    lea ecx, [eax + 24]
    mov [eax + applicative.header], dword applicative_header(6)
    mov [eax + applicative.program], dword rn_asm_applicative.L01x
    mov [eax + applicative.underlying], ecx
    mov [eax + applicative.var0], dword op_native_type_predicate.A0
    mov [eax + applicative.var1], dword op_native_type_predicate.A1
    mov [eax + applicative.var2], dword op_native_type_predicate.operate
    mov [ecx + operative.header], dword operative_header(6)
    mov [ecx + operative.program], dword op_native_type_predicate.operate
    mov [ecx + operative.var0], dword inert_tag ; ???
    mov [ecx + operative.var1], dword pred_encapsulated
    mov [ecx + operative.var2], edi
    mov [ecx + operative.var3], dword inert_tag
    ret

;;
;; app_encapsulate (continuation passing procedure)
;;
;; Implementation of encapsulator created by make-encapsulation-type.
;;
app_encapsulate:
  .A1:
    mov edi, [esi + operative.var1]
    mov ecx, 4
    call rn_allocate
    mov [eax + encapsulation.header], dword encapsulation_header(4)
    mov [eax + encapsulation.class], edi
    mov [eax + encapsulation.var0], ebx
    mov [eax + encapsulation.var1], dword inert_tag
    jmp [ebp + cont.program]

;;
;; app_decapsulate (continuation passing procedure)
;;
;; Implementation of decapsulator created by make-encapsulation-type.
;;
app_decapsulate:
  .A1:
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, encapsulation_header(0)
    jne .type_error
    mov eax, [ebx + encapsulation.class]
    mov edi, [esi + operative.var1]
    cmp eax, edi
    jne .class_error
    mov eax, [ebx + encapsulation.var0]
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error
  .class_error:
    mov eax, err_incompatible_encapsulation
    mov ecx, inert_tag
    jmp rn_error

;;
;; pred_encapsulated (native procedure)
;;
;; Procedure underlying the type predicate created
;; by (make-encapsulation-type).
;;
;; preconditions:  EAX = EBX = object
;;                 ESI = operative closure created by .pack_predicate
;;
;; postconditions: EAX = 1 if the class matches
;;                     = 0 if not
;;
;; preserves:      ??? ESI, EDI, EBP
;; clobbers:       ??? EAX, EFLAGS
;;
pred_encapsulated:
    test bl, 3
    jnz .no
    mov eax, [ebx]
    cmp al, encapsulation_header(0)
    jne .no
    mov eax, [ebx + encapsulation.class]
    cmp [esi + operative.var2], eax
    jne .no
    mov eax, 1
    ret
 .no:
    xor eax, eax
    ret
