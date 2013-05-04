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
;; rn_fixintP_procz
;; rn_numberP_procz
;;
;; preconditions:  EBX = object
;; postconditions: ZF = 1 and AL = 0 if object is a fixint
;;                 ZF = 1 and AL = 1 if object is a bigint
;;                 ZF = 1 and AL = 2 if object is an exact infinity
;;                 ZF = 0 if object is not a number
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
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

rn_numberP_procz:
    cmp bl, einf_tag
    jne rn_integerP_procz
    mov al, 2
    ret

;;
;; rn_siglog (native procedure)
;;
;; Returns sign and representation length of an integer
;; or exact infinity.
;;
;; preconditions:  EBX = object
;;
;; postconditions: ZF = 1 if EBX represents a number (fixint or bigint)
;;                 ZF = 0 if EBX is does not represent any number
;;                 EAX = S * M (untagged signed integer)
;;
;; where: S = sign of the number represented by EBX (-1, 0, or 1)
;;        M = 1 if EBX is fixint
;;        M = size of representation in 32-bit words,
;;            not including the header, if EBX is bigint
;;       |M| >= 0x00FFFFFF if EBX is infinite
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX, EFLAGS
;; stack usage:    2 (incl. call/ret)
;;
rn_siglog:
    test bl, 3
    jz .header
    cmp bl, einf_tag
    jz .infinite
    mov eax, ebx
    xor al, 1
    test al, 3
    jnz .done
    test eax, eax
    je .done
    sar eax, 31
    lea eax, [2*eax + 1]
    cmp eax, eax           ; set ZF = 1
  .done:
    ret
  .infinite:
    mov eax, ebx
    or eax, 0x0FFFFFFF
    cmp eax, eax           ; set ZF = 1
    ret
  .header:
    mov eax, [ebx]
    cmp al, bigint_header(0)
    jne .done
    shr eax, 8
    dec eax
    push edx
    mov edx, [ebx + 4 * eax]
    test edx, 0x80000000
    jz .positive_bigint
    neg eax
    cmp eax, eax          ; set ZF = 1
  .positive_bigint:
    pop edx
    ret

;;
;; rn_integer_compare
;;
;; Compare integers.
;;
;; preconditions:  EBX = integer X (fixint or bigint)
;;                 ECX = integer Y (fixint or bigint)
;;                 EDI = symbol for error reporting
;;
;; postcondition:  EAX = 0 if X = Y,
;;                     > 0 if X > Y,
;;                     < 0 if X < Y, if X and Y are integers
;;
;;                 EIP = rn_error if one if X or Y is not integer
;;
;; preserves:      ESI, EDI, EBP, DF
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS(except DF)
;;
rn_integer_compare:
    xchg ebx, ecx
    call rn_siglog
    jnz .nan
    mov edx, eax
    xchg ebx, ecx
    call rn_siglog
    jnz .nan
    sub eax, edx
    jne .done
    test bl, 3
    jz .bigint
  .fixint:
    mov eax, ebx
    sar eax, 2
    sar ecx, 2
    sub eax, ecx
  .done:
    ret
  .nan:
    mov eax, err_not_a_number
    mov ecx, edi
    push dword .nan
    jmp rn_error
  .bigint:
    push esi
    push edi
    mov edx, [ebx]
    shr edx, 8
    lea esi, [ebx + 4*edx - 8]
    lea edi, [ecx + 4*edx - 8]
    mov eax, [esi + 4]
    mov ebx, [edi + 4]
    sub eax, ebx               ; signed comparison
    jnz .bigint_done
    lea ecx, [edx - 2]
    std
    repe cmpsd
    cld
    mov eax, [esi + 4]
    mov ebx, [edi + 4]
    shr eax, 2                 ; unsigned comparison
    shr ebx, 2
    sub eax, ebx
  .bigint_done:
    pop edi
    pop esi
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
;; postconditions: EAX = the sum (freshly allocated bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    6 + ??? (incl. call/ret)
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
    push dword 0
    push dword 0
    shr eax, 8                      ; object length
    shr ebx, 8
    mov edx, ebx                    ; EDX := length of shorter obj
    mov ecx, eax
    sub ecx, ebx
    mov [esp + bi_add.ndiff], ecx   ; save difference
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
    mov ebp, [ebp - 4]              ; get most significand digit
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
;; preconditions:  EBX = 1st multiplicand (tagged fixint)
;;                 ECX = 2nd multiplicand (tagged fixint)
;;
;; postconditions: EAX = the product (fixint or bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_fixint_times_fixint:
    mov eax, ecx
    and al, ~3           ; clear tag bits
    sar ebx, 2           ; untag
    imul ebx
    jo .overflow
    or al, 1             ; tag as fixint
    ret
  .overflow:
    mov ebx, eax
    or bl, 1
    lea edx, [4*edx + 1]
    mov ecx, 4
    call rn_allocate
    mov ecx, edx
    bigint_extension ecx
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov [eax + bigint.digit1], edx
    mov [eax + bigint.digit2], ecx
    ret

;;
;; rn_bigint_umul (native procedure)
;;
;; Multiply bigint by an unsigned 32-bit integer.
;;
;; preconditions:  EBX = 1st multiplicand (untagged)
;;                 ESI = 2nd multiplicand (bigint)
;;                 2 <= EBX <= 2^31 - 1
;;
;; postconditions: EAX = the product (bigint or fixint in case EBX = 0)
;;
;; preserves:      EDI, EBP (!! allocates with invalid EBP !!)
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EFLAGS
;; stack usage:    O(size of input bigint)
;;
rn_bigint_umul:
    cmp ebx, 0
    je .zero
    cmp ebx, 1
    jne .regular_case
    mov eax, esi
    ret
  .zero:
    mov eax, fixint_value(0)
    ret
  .regular_case:
    push edi
    push ebp
    mov ebp, esp
    ;;
    ;; let N0 = 2p + 1 = number of digits of the input bigint I,
    ;;     M0 = N0 + 1 = 2p + 2 = its length (in dwords)
    ;;            4*M0 = 8p + 8 = its length (in bytes)
    ;;
    ;; Allocate space for two temporary bigints on the stack:
    ;;
    ;; T ... (N + 2) digits, M0 + 2 dwords =  8p + 16 bytes
    ;; S ....(N + 2) digits, M0 + 2 dwords =  8p + 16 bytes
    ;;               total 2*M0 + 2 dwords = 16p + 32 bytes
    ;;
    mov eax, [esi + bigint.header]
    mov ecx, eax         ; ECX := bigint_header(M0)
    xor cl, cl           ; ECX := 256 * M0
    shr ecx, 5           ; ECX := 8 * M0 = 16p + 16
    sub esp, ecx         ; ESP := EBP - 8 * M0
    lea esp, [esp - 16]  ; ESP := EBP - 8 * M0 - 16
    shr ecx, 4           ; ECX := p + 1
    dec ecx              ; ECX := p
    ;; Now, ECX = p, and ESP points to the lowest address
    ;; of the temporary space.
    ;;
    ;; header field of  S  is  [esp]
    ;;                  T      [esp + 8p + 16]
    ;;
    add eax, 0x200
    mov [esp], eax               ; header dword of S
    mov [esp + 8*ecx + 16], eax  ; header dword of T
    ;;
    ;; denote the 30-bit digits of the bigints by
    ;;
    ;;     X = [X(0), X(1), ..., X(2p-1), X(2p)]
    ;;     Y
    ;;     T = [T(0), T(1), ..., T(2p), T(2p+1), T(2p+2)]
    ;;     S = [S(0), S(1), ..., S(2p), S(2p+1), S(2p+2)]
    ;;
    ;;   T(2k) + 2^30 * T(2k+1) = X(2k) * Y, k = 0,1,..,p-1
    ;;   T(2p) + 2^30 * T(2p+1) = sign extension of X(2p) * Y
    ;;                  T(2p+2) = sign extension of X(2p)
    ;;
    ;;                     S(0) = 0
    ;; S(2k+1) + 2^30 * S(2k+2) = X(2k+1) * Y, k = 0,1,..,p-1
    ;;                  S(2p+1) = 0
    ;;                  S(2p+2) = 0
    ;;
    ;; X(k) is [(original esi) + 4*k + 4], k = 0, ... ,2p,
    ;; S(k) is [esp + 4*k + 4],            k = 0, ..., 2p + 2,
    ;; T(k) is [esp + 8*p + 4*k + 20],     k = 0, ..., 2p + 2
    ;;
    ;; Compute S(0), ..., S(2p) first.
    lea esi, [esi + 8*ecx + 8]      ; ESI := &X("2p+1")
    lea edi, [esp + 8*ecx + 8]      ; EDI := &S(2p+1)
    mov edx, fixint_value(0)
    mov [esp + bigint.digit0], edx  ; S(0) := 0
    mov [edi], edx                  ; S(2p+1) := 0
    mov [edi + 4], edx              ; S(2p+2) := 0
    call .sweep
    ;; now compute T(0), ..., T(2p-2)
    lea esi, [esi - 4]              ; ESI := &X(2p)
    lea edi, [ebp - 12]             ; EDI := &T(2p)
    call .sweep
    ;; compute T(2p+2)
    mov eax, [esi]                  ; EAX := X(2p)
    mov edx, eax
    bigint_extension edx            ; EDX := sign extension of X(2p)
    mov [ebp - 4], edx              ; store in T(2p+2)
    ;; compute T(2p) and T(2p+1)
    and al, ~3                      ; untag
    imul ebx                        ; multiply and sign extend
    or al, 1                        ; tag
    lea edx, [4*edx + 1]            ; tag
    mov [ebp - 12], eax             ; T(2p)
    mov [ebp - 8], edx              ; T(2p+1)
    ;; add S and T
    mov ebx, esp
    lea ecx, [esp + 8*ecx + 16]
    xor esi, esi                ; discard internal pointers, which
    xor edi, edi                ;   are not valid for the GC
    call rn_bigint_plus_bigint
    mov esp, ebp                ; discard bigints allocated on the stack
    pop ebp                     ; restore current cont.
    pop edi
    ret
  .sweep:
    push ecx
    neg ecx
  .uloop:
    mov eax, [esi + 8*ecx]
    and al, ~3
    mul ebx
    or al, 1
    lea edx, [4*edx + 1]
    mov [edi + 8*ecx], eax
    mov [edi + 8*ecx + 4], edx
    inc ecx
    jnz .uloop
    pop ecx
    ret

;;
;; rn_integer_shl_30 (native procedure)
;;
;; Multiply integer by 2^30.
;;
;; preconditions:  EBX = X = integer (bigint or fixint)
;;
;; postconditions: EAX = X * 2^30 (bigint or fixint)
;;
;; preserves:      EBX, ESI, EDI, EBP
;; clobbers:       EAX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_integer_shl_30:
    test bl, 3
    jz .bigint
    cmp ebx, fixint_value(0)
    je .zero
  .nonzero_fixint:
    mov ecx, 4
    call rn_allocate
    mov ecx, ebx
    bigint_extension ecx
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], dword fixint_value(0)
    mov [eax + bigint.digit1], ebx
    mov [eax + bigint.digit2], ecx
    ret
  .zero:
    mov eax, ebx
    ret
  .bigint:
    push esi
    push edi
    mov edx, [ebx]
    mov ecx, edx
    shr ecx, 8
    mov eax, [ebx + 4*ecx - 8]
    bigint_extension eax
    cmp [ebx + 4*ecx - 4], eax
    jne .bigger
  .same_size:
    call rn_allocate
    mov [eax + bigint.header], edx
  .copy:
    mov [eax + bigint.digit0], dword fixint_value(0)
    lea esi, [ebx + bigint.digit0]
    lea edi, [eax + bigint.digit1]
    dec ecx
    rep movsd
    pop edi
    pop esi
    ret
  .bigger:
    lea ecx, [ecx + 2]
    call rn_allocate
    lea ecx, [ecx - 2]
    add edx, 0x200
    mov [eax + bigint.header], edx
    mov edx, [ebx + 4*ecx - 4]
    mov [eax + 4*ecx], edx
    bigint_extension edx
    mov [eax + 4*ecx + 4], edx
    jmp .copy

;;
;; rn_bigint_times_fixint (native procedure)
;;
;; Multiply bigint by a fixint.
;;
;; preconditions:  EBX = 1st multiplicand (bigint)
;;                 ECX = 2nd multiplicand (tagged fixint)
;;
;; postconditions: EAX = the product (bigint or zero)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_fixint_times_bigint:
    xchg ebx, ecx
rn_bigint_times_fixint:
    cmp ecx, fixint_value(0)
    je .zero
    cmp ecx, fixint_value(1)
    je .plus1
    cmp ecx, fixint_value(-1)
    je rn_negate_bigint
    push esi
    test ecx, ecx
    js .negative
  .positive:
    mov esi, ebx
    mov ebx, ecx
    shr ebx, 2
  .multiply:
    call rn_backup_cc
    call rn_bigint_umul.regular_case
    call rn_restore_cc
    pop esi
    ret
  .negative:
    push ecx
    mov ecx, [ebx]
    call rn_negate_bigint.no_fixint
    mov esi, eax
    pop ebx
    sar ebx, 2
    neg ebx
    jmp .multiply
  .zero:
    mov eax, ecx
    ret
  .plus1:
    mov eax, ebx
    ret

;;
;; rn_bigint_times_bigint (native procedure)
;;
;; Multiply two bigints.
;;
;; preconditions:  EBX = X = 1st multiplicand (bigint)
;;                 ECX = Y = 2nd multiplicand (bigint)
;;
;; postconditions: EAX = the product (bigint or zero)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_bigint_times_bigint:
    mov eax, [ebx]
    mov edx, [ecx]
    cmp eax, edx
    jbe .ordered
    xchg ebx, ecx               ; ensure length(X) <= length(Y)
  .ordered:
    call rn_backup_cc
    push esi
    push edi
    push ebp
    mov ebp, ebx                ; EBP := X
    mov esi, ecx                ; ESI := Y
    mov edi, [ebx]              ; EDI := header word of X
    shr edi, 8                  ; EDI := object length of X
    dec edi                     ; EDI := digit count of X
    mov ecx, [ebp + 4*edi]      ; ECX := most signif. digit of X
    cmp ecx, fixint_value(0)
    je .skip_zero_terms
    mov ebx, esi                ; EBX := Y
    call rn_bigint_times_fixint ; EAX := Y * most signif. digit
    dec edi                     ;   (compute with sign extension)
  .next_unsigned_term:          ; EAX is a bigint, or nonzero fixint here
    mov ebx, eax                ; EBX := accumulated value from h.o. terms
    call rn_integer_shl_30      ; EAX := acc * 2^30
    mov ebx, [ebp + 4*edi]      ; EBX := lower-order digit of X
    cmp ebx, fixint_value(0)    ; skip multiply-add operation
    je .noadd                   ;   if the digit is zero
    push eax
    shr ebx, 2                  ; untag
    push esi
    call rn_bigint_umul         ; EAX := digit * Y
    pop esi
    pop ebx                     ; EBX := acc
    mov ecx, eax
    call rn_bigint_plus_bigint  ; EAX := 2^30 * acc + digit * Y
  .noadd:
    dec edi                     ; move to next digit
    jnz .next_unsigned_term
    pop ebp
    pop edi
    pop esi
    call rn_restore_cc
    ret
  .skip_zero_terms:
    dec edi                     ; EDI := digit count of X
    mov ebx, [ebp + 4*edi]      ; EBX := most signif. digit of X
    cmp ebx, fixint_value(0)
    je .skip_zero_terms
    shr ebx, 2                  ; untag
    push esi
    call rn_bigint_umul         ; EAX := most signif. digit * Y
    pop esi
    jmp .noadd

;;
;; rn_negate_fixint (native procedure)
;;
;; Compute (-X) for fixint X.
;;
;; preconditions:  EBX = operand X (fixint)
;; postconditions: EAX = result (-X) (fixint or bigint)
;;
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; clobbers:       EAX
;; stack usage:    ??? (incl. call/ret)
;;
rn_negate_fixint:
    cmp ebx, fixint_value(min_fixint)
    je .bigint_result
    mov eax, ebx
    xor eax, 0xFFFFFFFC
    lea eax, [eax + 4]
    ret
  .bigint_result:
    push ecx
    mov ecx, 4
    call rn_allocate
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov ecx, fixint_value(0)
    mov [eax + bigint.digit1], ecx
    mov [eax + bigint.digit2], ecx
    pop ecx
    ret

;;
;; rn_negate_bigint (native procedure)
;;
;; Compute (-X) for bigint X.
;;
;; preconditions:  EBX = operand X (bigint)
;; postconditions: EAX = result (-X) (fixint or bigint)
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    ??? (incl. call/ret)
;;
rn_negate_bigint:
    mov ecx, [ebx]
    cmp ecx, bigint_header(4)
    ja .no_fixint
    mov eax, fixint_value(min_fixint)
    cmp [ebx + bigint.digit0], eax
    jne .no_fixint
    mov edx, fixint_value(0)
    cmp [ebx + bigint.digit1], edx
    jne .no_fixint
    cmp [ebx + bigint.digit2], edx
    jne .no_fixint
    ret
  .no_fixint:
    mov edx, ecx
    shr ecx, 8
    call rn_allocate
    push esi
    push edi
    push eax
    mov [eax], edx
    lea esi, [ebx + bigint.digit0]
    lea edi, [eax + bigint.digit0]
    jmp .L
  .zero:
    mov [edi], eax
    lea esi, [esi + 4]
    lea edi, [edi + 4]
  .L:
    dec ecx
    mov eax, [esi]
    cmp eax, fixint_value(0)
    je .zero
    cmp eax, fixint_value(min_fixint)
    je .min_digit
    xor eax, 0xFFFFFFFC
    lea eax, [eax + 4]
    mov [edi], eax
    dec ecx
    jecxz .done
  .invert:
    lea esi, [esi + 4]
    lea edi, [edi + 4]
    mov eax, [esi]
    xor eax, 0xFFFFFFFC
    mov [edi], eax
    loop .invert
  .done:
    pop eax
    pop edi
    pop esi
    ret
  .min_digit:
    mov [edi], eax
    cmp ecx, 1
    jnz .invert
  .append_more_digits:
    pop eax
    lea edx, [edx + (2 << 8)]
    mov [eax], edx
    mov ebx, fixint_value(0)
    mov [edi + 4], ebx
    mov [edi + 8], ebx
    mov esi, [lisp_heap_pointer]
    lea esi, [esi + 8]
    mov [lisp_heap_pointer], esi
    pop edi
    pop esi
    ret

;;
;; bigint_shift_step TEMP-REG (macro)
;;
;; preconditions:  EAX = fixint_value(A1) & ~3
;;                 EBX = fixint_value(A0) & ~3
;;                 CL = K0, 0 <= K0 < 30
;;                 CH = K1 = 30 - K0
;;                 TMP-REG = register name EDX, ESI, EDI or EBP
;;
;; postconditions: EAX = fixint_value((A0 >> K0) | (A1 << K1)) & ~3
;;                 EBX = fixint_value(A1) | P (for some P = 0,1,2,3)
;;
;; clobbers:  EAX, EBX, TEMP-REG (macro argument), EFLAGS
;; preserves: ECX, {EDX, ESI, EDI, EBP} \ {TMP-REG}
;;

%macro bigint_shift_step 1
    shr ebx, cl
    xchg ch, cl
    mov %1, eax
    shl eax, cl
    xchg ch, cl
    or eax, ebx
    mov ebx, %1
%endmacro

;;
;; rn_bigint_shift_right (native procedure)
;;
;; preconditions:  EBX = input bigint
;;                 ECX = H := shift (untagged, unsigned)
;; postconditions: EAX = output bigint or fixint
;;
;; preserves:      EBP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
;;
rn_bigint_shift_right:
    mov esi, ebx                 ; ESI := input bigint
    mov eax, ecx                 ; EAX = H
    xor edx, edx                 ; EDX:EAX = H
    mov ebx, 30
    div ebx                      ; (EAX, EDX) := (H div 30, H mod 30)
    mov ebx, eax                 ; EBX := H div 30
    mov ecx, [esi]               ; ECX := header word of input bigint
    shr ecx, 8                   ; ECX := length of input bigint object
    mov edi, [esi + 4*ecx - 4]   ; EDI := most significant digit
    bigint_extension edi         ; EDI := sign extension of input
    sub ecx, ebx                 ; ECX := length of output object
    mov eax, ecx                 ; EAX := ... necessary to hold the result
    cmp ecx, 2
    jl .shift_out
    jg .not_too_small
    inc ecx                      ; ensure length >= 4 dwords
  .not_too_small:
                                 ; reserve space for:
    push edi                     ;   [esp + 12] = saved sign extension
    push ebp                     ;   [esp + 8] = saved EBP
    push ebp                     ;   [exp + 4] = pointer to new object
    push ebp                     ;   [esp + 0] = # of digits - 1
    inc ecx                      ; align length
    and ecx, ~1                  ;   to a multiple of 2 dwords
    sub eax, 2                   ; number of 30-bit digits - 1
    mov [esp], eax               ; save number of digits
    call rn_allocate             ; allocate output object
    mov [esp + 4], eax           ; save pointer to the new object
    xchg edi, eax                ; EDI := new object, EAX := sign extension
    mov [edi + 4*ecx - 4], eax   ; write sign extension
    mov [edi + 4*ecx - 8], eax   ;   in top 2 words
    mov eax, ecx                 ; prepare object header
    shl eax, 8                   ;  ...
    mov al, bigint_header(0)     ;  ...
    mov [edi], eax               ; write object header
    lea esi, [esi + 4 * ebx + 8] ; pointer to least-significant-but-one used digit of input
    mov ebx, [esi - 4]           ; get least significant digit
    and ebx, ~3                  ; clear tag bits
    mov ecx, edx                 ; ECX := H mod 30
    mov ch, 30                   ; CH := 30 - (H mod 30)
    sub ch, cl                   ;   ...
    mov edx, [esp]               ; EDX = number of digits - 1
    lea esi, [esi + 4*edx]
    lea edi, [edi + 4*edx + 4]
  .main:
    test edx, edx
    jz .last_digit
    neg edx                      ; count up towards zero
  .shift_next:
    mov eax, [esi + 4*edx]
    and eax, ~3                  ; clear tag bits
    bigint_shift_step ebp
    and eax, ~3                  ; add tag
    or eax, 1                    ;   ...
    mov [edi + 4*edx], eax       ; store digit
    inc edx
    jnz .shift_next
  .last_digit:
    mov eax, [esp + 12]          ; get sign extension
    and eax, ~3                  ; clear tag bits
    bigint_shift_step ebp        ; combine into last digit
    and eax, ~3                  ; add tag
    or eax, 1                    ;   ...
    mov [edi], eax               ; store digit
    mov ebx, [esp + 4]           ; new object
    mov ebp, [esp + 8]           ; restore register EBP
    add esp, 16                  ; restore stack
    jmp bi_normalize            ; normalize bigint
  .shift_out:
    mov eax, edi
    ret

;;
;; rn_bigint_shift_left (native procedure)
;;
;; preconditions:  EBX = input bigint
;;                 ECX = H := shift (untagged, unsigned)
;; postconditions: EAX = output bigint or fixint
;;
;; preserves:      EBP
;; clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
;;
rn_bigint_shift_left:
    mov esi, ebx                 ; ESI := input bigint
    mov eax, ecx                 ; EAX = H
    xor edx, edx                 ; EDX:EAX = H
    mov ebx, 30
    div ebx                      ; (EAX, EDX) := (H div 30, H mod 30)
    mov ebx, eax                 ; EBX := H div 30
    mov ecx, [esi]               ; ECX := header word of input bigint
    shr ecx, 8                   ; ECX := length of input bigint object
    mov edi, [esi + 4*ecx - 4]   ; EDI := most significant digit
    bigint_extension edi         ; EDI := sign extension of input
    add ecx, ebx                 ; ECX := length of output object
    mov eax, ecx                 ; EAX := ... necessary to hold the result - 1
                                 ; reserve space for:
    push edi                     ;   [esp + 12] = saved sign extension
    push ebp                     ;   [esp + 8] = saved EBP
    push ebp                     ;   [exp + 4] = pointer to new object
    push ebp                     ;   [esp + 0] = # of digits - 1
    add eax, 2                   ; align length
    and ecx, ~1                  ;   to a multiple of 2 dwords
    dec eax                      ; number of 30-bit digits - 1
    mov [esp], eax               ;   save it
    call rn_allocate             ; allocate output object
    mov [esp + 4], eax           ; save pointer to the new object
    xchg edi, eax                ; EDI := new object, EAX := sign extension
    mov [edi + 4*ecx - 4], eax   ; write sign extension
    mov [edi + 4*ecx - 8], eax   ;   in top 2 words
    mov eax, ecx                 ; prepare object header
    shl eax, 8                   ;  ...
    mov al, bigint_header(0)     ;  ...
    stosd                        ; write object header
    mov eax, fixint_value(0)     ; write (H div 30)
    mov ecx, ebx                 ;   zero
    rep stosd                    ;   digits
    xor ebx, ebx                 ; value to shift in
    mov ecx, edx                 ; ECX := H mod 30
    mov ch, 30
    sub ch, cl                   ; CL := 30 - (H mod 30)
    xchg ch, cl                  ; CH := H (mod 30)
    mov edx, [esp]               ; EDX = number of digits - 1
    lea esi, [esi + 4*edx + 4]
    lea edi, [edi + 4*edx]
    jmp rn_bigint_shift_right.main

;;
;; rn_u64_to_bigint
;;
;; preconditions:  EAX = low 32-bits
;;                 EDX = high 32-bits
;;                 EBP = current continuation (for error handling)
;;
;; postconditions: EAX = bigint or fixint representation
;;
;; preserves: ESI, EDI, EBP
;; clobbers: EAX, EBX, ECX, EDX, EFLAGS
;;
rn_u64_to_bigint:
    push esi
    push edi
    mov esi, edx
    mov edi, eax
    mov ecx, 4
    call rn_allocate
    lea ebx, [4 * edi + 1]
    shrd edi, esi, 30
    shr esi, 30
    lea ecx, [4 * edi + 1]
    shrd edi, esi, 30
    lea edx, [4 * edi + 1]
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov [eax + bigint.digit1], ecx
    mov [eax + bigint.digit2], edx
    pop esi
    pop edi
    mov ebx, eax
    jmp bi_normalize
