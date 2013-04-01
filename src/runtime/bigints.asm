;;;
;;; bigints.asm
;;;
;;; 2-complement integers of arbitrary magnitude.
;;;
;;; An integer x is represented by
;;;
;;;  fixint_value(x),              if  -2^30 <= x <= 2^30 - 1
;;;
;;;  allocated object              if  -2^90 <= x <= -2^30 - 1
;;;   {H(4), D[0], D[1], D[2]},    or   2^30 <= x <= 2^90 - 1
;;;
;;;  allocated object
;;;   {H(n+1), D[0], ..., D[n-1]}, if     -2^(30*n) <= x <= -2^(30*(n-2)) - 1
;;;                                or  2^(30*(n-2)) <= x <= 2^(30*n) - 1
;;;   where n = 2k + 1,
;;;         k = 2, 3, ...
;;;         H(s) = bigint_header(s)
;;;         D[j] = fixint_value(d[j])
;;;   and
;;;            x = d[0]
;;;                + 2^30 * d[1]
;;;                + ...
;;;                + 2^(30*(n - 1))* LSB(d[n-1])
;;;                - 2^(30*n - 1) * MSB(d[n-1])
;;;       MSB(v) = v >> 2^29
;;;       LSB(v) = v & (2^29 - 1)
;;;

;;
;; rn_integerP_procz (native procedure)
;;
;; TODO
;;
rn_integerP_procz:
    test ebx, 3
    jz .header
  .noheader:
    mov eax, ebx
    xor al, 1
    and al, 3
    ret
  .header:
    mov eax, [ebx]
    cmp al, bigint_header(0)
    mov al, 1
    ret

rn_fixintP_procz:
    mov eax, ebx
    xor al, 1
    test al, 3
    ret

;;
;; normalize_loop SIGN (native procedure)
;;
;; preconditions:   EBX = input bigint object representing
;;                        an integer X
;;                  ECX = object length (untagged integer)
;;                 SIGN = 0 if X >= 0
;;                        -1 if X < 0
;;
;; postconditions:  ECX = minimal object length necessary
;;                        for representation of the number
;;
;; preserves:       EDX, ESI, EDI, EBP
;; clobbers:        EAX, EBX, ECX, EDX, EFLAGS
;;
%macro normalize_loop 1
  %%next:
    mov eax, [ebx + 4*ecx - 8]   ; Check two most siginficant
    cmp eax, fixint_value(%1)    ;   (base 2^30) digits. If
    jne %%done                   ;   all bits are set to zeros
    mov eax, [ebx + 4*ecx - 4]   ;   (or ones, respectively),
    cmp eax, fixint_value(%1)    ;   ...
    jne %%done                   ;   ...
    mov eax, [ebx + 4*ecx - 12]  ; and the sign (most significant
    test eax, eax                ;   bit) of the preceding digit
  %if (%1 == 0)                  ;   matches, the two digits
    js %%done                    ;   can be removed.
  %elif (%1 == -1)
    jns %%done
  %else
    %error "macro parameter must be 0 or -1"
  %endif
    sub ecx, 2
    jmp %%next
  %%done:
%endmacro

;;
;; bi_normalize (native procedure)
;;
;; preconditions:   EBX = input bigint object
;;
;; postconditions:  EAX = bigint object of minimal length
;;                        or fixint equal to the input number
;;
;; preserves:       ESI, EDI, EBP
;; clobbers:        EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:     1 (incl. call/ret)
;;
bi_normalize:
    mov ecx, [ebx + bigint.header]
    shr ecx, 8                     ; object length
    mov edx, ecx
    mov eax, [ebx + 4*ecx - 4]     ; get most significant digit
    test eax, eax
    js .negative
    normalize_loop 0               ; normalize nonnegative
    jmp .finish
  .negative:
    normalize_loop -1              ; normalize negative
  .finish:
    cmp ecx, edx                   ; should length change?
    je .done
    cmp ecx, 2                     ; length 2 is enough?
    je .fixint
  .shrink:
    mov eax, ecx                   ; compute new header word
    shl eax, 8
    mov al, bigint_header(0)
    mov [ebx], eax                 ; store new header word
    lea eax, [ebx + 4*edx]         ; pointer past object + old size
    cmp [lisp_heap_pointer], eax   ; it is heap end?
    jne .done
    lea eax, [ebx + 4*ecx]         ; pointer past object + new size
    mov [lisp_heap_pointer], eax   ; bump free pointer back
  .done:
    mov eax, ebx
    ret
  .fixint:
    mov eax, [ebx + bigint.digit0] ; fixint is enough
    ret

;;
;; fixint_adc (macro)
;;
;; Add two fixints with carry.
;;
;; preconditions:  EAX = 1st 30-bit summand (tagged fixint)
;;                 EBX = 2nd 30-bit summand (tagged fixint)
;;                 ECX = carry bit (untagged integer 0 or 1)
;;
;; postconditions: EAX = low 30 bits of the sum (tagged fixint)
;;                 ECX = carry bit (untagged integer 0 or 1)
;;
;; preserves:      EDX, ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EFLAGS
;;
%macro fixint_adc 0
    lea eax, [eax + 2 * ecx - 1] ; split carry between addends to avoid
    lea ebx, [ebx + 2 * ecx]     ;   overflow and compensate for the tag
    add eax, ebx                 ; compute digit of the sum
    setc cl                      ; save carry in ECX
%endmacro

;;
;; bigint_extension REG (macro)
;;
;; Compute sign extension word.
;;
;; preconditions:  register %1 = tagged fixint
;;
;; postconditions: register %1 = fixint_value(0) if input >= 0
;;                             = fixint_value(-1) if input < 0
;;
;; preserves:      all registers except %1 and EFLAGS
;; clobbers:       register %1 and EFLAGS
;;
%macro bigint_extension 1
    sar %1, 30
    and %1, ~3
    or  %1,  1
%endmacro

;;
;; rn_bigint_plus_bigint (native procedure)
;;
;; Add two bigints.
;;
;; preconditions:  EBX = first summand (bigint)
;;                 ECX = 2nd summand (bigint)
;;
;; postconditions: EAX = 3rd summand (bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    6 (incl. call/ret)
;;

%define bi_add.ndiff   0
%define bi_add.result  4

rn_bigint_plus_bigint:
    push esi
    push edi
    push ebp
    mov esi, ebx      ; ESI := 1st summand
    mov ebp, ecx      ; EBP := 2nd summand
    mov eax, [esi]
    mov ebx, [ebp]
    cmp eax, ebx
    jae .ordered
    xchg esi, ebp     ; ensure EAX = [ESI] >= EBX = [EBP]
    xchg eax, ebx
  .ordered:
    ;; make room for 2 variables:
    ;;    ndiff  = max(len1, len2) - min(len1, len2)
    ;;    sumobj = pointer to the sum object
    ;;
    ;; The variables nshort and ndiff are negative multiples
    ;; of two.
    ;;
    sub esp, 8
    shr eax, 8                      ; object length
    shr ebx, 8
    mov edx, ebx                    ; EDX := length of shorter obj
    sub ebx, eax
    mov [esp + bi_add.ndiff], ebx   ; save difference
    lea ecx, [eax + 2]              ; create object for the result
    call rn_allocate                ;  with 2 more words
    mov [esp + bi_add.result], eax  ;  to accomodate overflow
    mov edi, eax                    ; EDI := new object
    shl ecx, 8                      ; store header
    mov  cl, bigint_header(0)       ;  in the new
    mov [eax + bigint.header], ecx  ;  object
    ;;
    ;; stage 1:
    ;;   add digits from both summands
    ;;
    xor ecx, ecx                    ; carry is initially zero
    mov eax, [esi + bigint.digit0]  ; get first pair of digits
    mov ebx, [ebp + bigint.digit0]  ;
    fixint_adc                      ; EAX, ECX := EAX + EBX + ECX
    mov [edi + bigint.digit0], eax  ; store result
    lea ebp, [ebp + 4 * edx]        ; pointer at the end of shorter object
    lea esi, [esi + 4 * edx]        ;  analogous pointer to longer object
    lea edi, [edi + 4 * edx]        ;  and to the result object
    shr edx, 1                      ; EDX := - (length/2 - 1)
    dec edx                         ;  ...
    neg edx                         ;  ...
  .L1:
    mov eax, [esi + 8 * edx]        ; get next pair
    mov ebx, [ebp + 8 * edx]
    fixint_adc
    mov [edi + 8 * edx], eax
    mov eax, [esi + 8 * edx + 4]    ; get next pair
    mov ebx, [ebp + 8 * edx + 4]
    fixint_adc
    mov [edi + 8 * edx + 4], eax
    inc edx                         ; increment towards zero
    jnz .L1
    ;;
    ;; stage 2:
    ;;   add digits from the longer summand with sign extension
    ;;   of the shorter summand
    ;;
    mov ebx, [ebp - 4]              ; get most significand digit
    bigint_extension ebp            ; compute sign extension word
    mov edx, [esp + bi_add.ndiff]
    test edx, edx
    jz .L3
    lea esi, [esi + 4 * edx]
    lea edi, [edi + 4 * edx]
    shr edx, 1
    neg edx
  .L2:
    mov eax, [esi + 8 * edx]        ; next digit
    mov ebx, ebp                    ; sign extension word
    fixint_adc                      ; add, with carry in ECX
    mov [edi + 8 * edx], eax        ; store result digit
    mov eax, [esi + 8 * edx + 4]    ; next digit
    mov ebx, ebp                    ;   ...
    fixint_adc
    mov [edi + 8 * edx + 4], eax
    inc edx
    jnz .L2
    ;;
    ;; stage 3:
    ;;   compute the last pair of digits from carry bit
    ;;   and sign extensions of the inputs
    ;;
  .L3:
    mov esi, [esi - 4]              ; get most significant digit
    bigint_extension esi            ; compute sign exension
    mov eax, esi
    mov ebx, ebp
    fixint_adc                      ; add, with carry in ECX
    mov [edi], eax                  ; store result digit
    mov eax, esi
    mov ebx, ebp
    fixint_adc
    mov [edi + 4], eax
    ;;
    ;; stage 4:
    ;;   normalize the result if necessary
    ;;
    mov ebx, [esp + bi_add.result]  ; get result object
    add esp, 8                      ; discard local variables
    pop ebp
    pop edi
    pop esi
    jmp bi_normalize

;;
;; rn_fixint_plus_fixint (native procedure)
;;
;; Add two fixints, producing bigint on overflow.
;;
;; preconditions:  EBX = 1st summand (tagged fixint)
;;                 ECX = 2nd summand (tagged fixint)
;;
;; postconditions: EAX = sum (fixint or bigint)
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    4 (incl. call/ret)
;;
rn_fixint_plus_fixint:
    mov eax, ecx
    dec eax
    add eax, ebx
    jo .overflow
    ret
  .overflow:
    push ebx
    push ecx
    push edx
    mov ebx, eax
    jnc .positive
    mov edx, fixint_value(-1)
    jmp .allocate
  .positive:
    mov edx, fixint_value(0)
  .allocate:
    mov ecx, 4
    call rn_allocate
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov [eax + bigint.digit1], edx
    mov [eax + bigint.digit2], edx
    pop edx
    pop ecx
    pop ebx
    ret

;;
;; rn_bigint_plus_fixint (native procedure)
;;
;; Add bigint with fixint.
;;
;; preconditions:  EBX = 1st summand (bigint)
;;                 ECX = 2nd summand (tagged fixint)
;;
;; postconditions: EAX = sum (fixint or bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EFLAGS
;; stack usage:    10 dwords (incl. call/ret)
;;
rn_fixint_plus_bigint:
    xchg ecx, ebx
rn_bigint_plus_fixint:
    mov eax, ecx
    bigint_extension eax
    push eax
    push eax
    push ecx
    push dword bigint_header(4)   ; fake bigint on the stack
    mov ecx, esp
    call rn_bigint_plus_bigint
    add esp, 16
    ret

;;
;; rn_fixint_times_fixint (native procedure)
;;
;; Multiply two fixints, producing bigint on overflow.
;;
;; preconditions:  EBX = 1st summand (tagged fixint)
;;                 ECX = 2nd summand (tagged fixint)
;;
;; postconditions: EAX = the product (fixint or bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_fixint_times_fixint:
    mov eax, ecx
    sar eax, 2           ; untag
    sar ebx, 2           ; untag
    imul ebx
    jo .overflow
    lea eax, [4*eax + 1] ; tag as fixint
    ret
  .overflow:
    mov ebx, eax
    mov ecx, 4
    call rn_allocate
    mov ecx, edx
    bigint_extension ecx
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov [eax + bigint.digit1], edx
    mov [eax + bigint.digit1], ecx
    ret
