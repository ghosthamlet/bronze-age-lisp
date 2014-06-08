;;;
;;; hash-functions.asm
;;;
;;; Hash functions compatible with equal?.
;;;

;;
;; rn_hash (native procedure)
;;
;; Compute hash value of arbitrary object, depending on a 128-bit key.
;;
;; preconditions:  EBX = object
;;                 ECX = fuel (untagged)
;;                 ESI = address of the key
;;
;; postconditions: EBX:EAX = hash value (untagged)
;;
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; preserves:      ESI, EDI, EBP
;;
rn_hash:
    ;rn_trace 1, 'hash', hex, ebx, hex, ecx
    push esi
    push edi
    push ebp
    sub esp, 32
    mov ebp, esp
    push ebx
    push ecx
    call siphash_init
    pop ecx
    pop ebx
    call .recurse
    call siphash_finish
    add esp, 32
    pop ebp
    pop edi
    pop esi
    xor ecx, ecx
    xor edx, edx
    ret

    ;;
    ;; .recurse preconditions:  EBX = object
    ;;                          ECX = fuel
    ;;                          EBP = address of SipHash internal state
    ;;
    ;;          postconditions: object hashed into internal state
    ;;          clobbers:       EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
    ;;          preserves:      EBP
    ;;          stack usage:    O(1 + fuel)
    ;;
  .recurse:
    jecxz .out_of_fuel
    test bl, 3
    jz .aligned
    jp .pair
    mov al, bl
    xor al, symbol_tag
    test al, ~(symbol_tag ^ bytevector_tag)
    je .blob
  .immediate:
    mov esi, ebx
    jmp siphash_step_reg32
  .out_of_fuel:
    mov esi, 'fuel'
    jmp siphash_step_reg32

  .pair:
    mov edx, ecx
    shr ecx, 2
    sub edx, ecx
    dec edx
    push edx
    push dword cdr(ebx)
    mov ebx, car(ebx)
    call .recurse
    pop ebx
    pop ecx
    jmp .recurse

  .blob:
    mov edx, ebx              ; save tagged value
    call rn_get_blob_data
    mov al, cl                ; combine low-order bits of length with
    and al, 0xF               ; some bits from the tag, so a keyword
    shl dl, 4                 ; string, symbol and bytevector with the
    or  dl, al                ; same characters get different hashes
    push edx                  ; save tag/length hash
  .blob_aux:
    mov esi, ebx
    mov edx, ecx
    add ecx, 8
    shr ecx, 3
    dec ecx
    lea eax, [8*ecx]
    sub edx, eax
    jecxz .blob_finish
    push edx                  ; save number of remaining bytes for the last step
  .blob_loop:
    push ecx
    call siphash_step_mem64
    pop ecx
    lea esi, [esi + 8]        ; advance to next 64-bit word
    loop .blob_loop
    pop edx                   ; restore number of remaining bytes
  .blob_finish:
    mov edi, scratchpad_start ; build the last 64-bit word
    mov [edi], dword 0
    mov [edi + 4], dword 0
    mov ecx, edx
    rep movsb                 ; copy remaining bytes
    pop ecx                   ; restore tag/length hash
    mov byte [scratchpad_start + 7], cl    ; copy tag/length hash in
    mov esi, scratchpad_start
    jmp siphash_step_mem64    ; hash the word

  .aligned:
    mov eax, [lisp_heap_pointer]
    xor eax, ebx
    test eax, ~(configured_lisp_heap_size - 1)
    jnz .immediate
  .header:
    mov edx, [ebx]
    cmp dl, bigint_header(0)
    je .bigint
    cmp dl, vector_header(0)
    je .vector
    cmp dl, applicative_header(0)
    je .applicative
    cmp dl, cont_header(0)
    je .continuation
    cmp dl, operative_header(0)
    je .vector
    mov esi, ebx
    jmp siphash_step_mem64

  .bigint:
    mov esi, ebx
    mov ecx, [ebx]
    shr ecx, 9
  .bigint_loop:
    push ecx
    call siphash_step_mem64
    pop ecx
    lea esi, [esi + 8]
    loop .bigint_loop
    ret

  .vector:
    shr ecx, 1
    push ecx
    push ebx
    mov ecx, [ebx]
    shr ecx, 8
  .vector_loop:
    push ecx
    mov ecx, [esp + 8]
    mov esi, [esp + 4]
    mov ebx, [esi]
    call .recurse
    mov esi, [esp + 4]
    lea esi, [esi + 4]
    mov [esp + 4], esi
    pop ecx
    loop .vector_loop
    add esp, 8
    ret

  .applicative:
    dec ecx
    push dword [ebx + applicative.underlying]
    push ecx
    mov esi, edx
    call siphash_step_reg32
    pop ecx
    pop ebx
    jmp .recurse

  .continuation:
    dec ecx
    mov esi, ebx
    push ecx
    call siphash_step_mem64
    pop ecx
    mov ebx, [esi + cont.parent]
    jmp .recurse

;;
;; rn_hash_buffer (native procedure)
;;
;; Compute hash value of a memory buffer.
;;
;; preconditions:  EBX = address of input buffer
;;                 ECX = length of buffer in bytes
;;                 ESI = address of key (128-bit)
;;
;; postconditions: EBX:EAX = hash value (untagged)
;;
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; preserves:      ESI, EDI, EBP
;;
rn_hash_buffer:
    push esi
    push edi
    push ebp
    sub esp, 32
    mov ebp, esp
    call .aux
    call siphash_finish
    add esp, 32
    pop ebp
    pop edi
    pop esi
    xor ecx, ecx
    xor edx, edx
    ret
  .aux:
    push ecx
    push ebx
    call siphash_init
    pop ebx
    mov ecx, [esp]            ; leave length for the last SipHash word
    jmp rn_hash.blob_aux

;;
;; Implementation of SipHash algorithm.
;;
;; Based on algorithm description and reference C language
;; implementation from https://131002.net/siphash/.
;;
;; The description uses the notation
;;
;;   X + Y   ... sum of X and Y modulo 2^64
;;   X ^ Y   ... bitwise xor of X and Y operation
;;   X <<< R ... rotation of X by R bits in a 64-bit word
;;   X op= Y ... perform (X op Y) and store the result in X
;;
;; The internal state of SipHash consists of four 64-bit variables
;; v0, v1, v2, v3.
;;
;; SipHashC, SipHashD        algorithm parameters (SipHash-c-d)
;;
;; SipStateLo(K)             effective address of low 32-bits of vK
;; SipStateHi(K)             effective address of high 32-bits of vK
;;
;; SipLoad REGLO, REGHI, K   load vK in REGHI:REGLO
;; SipStore REGLO, REGHI, K  store REGHI:REGLO in vK
;;
;; SipMix R                  perform vI += vJ, vJ <<<= R, vJ ^= vI
;; SipRound                  perform one "SipRound" transform of the
;;                           internal state (see [1] section 2).
;;

%define SipHashC 2
%define SipHashD 4

;%define SipHashC 4
;%define SipHashD 8

%define SipStateLo(k) [ebp + 8*k]
%define SipStateHi(k) [ebp + 8*k + 4]

%macro SipLoad 3
    mov %1, SipStateLo(%3)
    mov %2, SipStateHi(%3)
%endmacro

%macro SipStore 3
    mov SipStateLo(%3), %1
    mov SipStateHi(%3), %2
%endmacro

%macro SipMix 1
    add eax, ecx
    adc ebx, edx
    mov edi, edx
    shld edx, ecx, %1
    shld ecx, edi, %1
    xor ecx, eax
    xor edx, ebx
%endmacro

%macro SipRound 0
    SipLoad eax, ebx, 0    ; load v0
    SipLoad ecx, edx, 1    ; load v1
    SipMix 13              ; v0 += v1, v1 <<<= 13, v1 ^= v0
    SipStore ebx, eax, 0   ; store (v0 <<< 13)
    SipStore ecx, edx, 1   ; store v1
                           ; .
    SipLoad eax, ebx, 2    ; load v2
    SipLoad ecx, edx, 3    ; load v3
    SipMix 16              ; v2 += v3, v3 <<<= 16, v3 ^= v2
                           ; (store v2)
    SipStore ecx, edx, 3   ; store v3
                           ; .
                           ; (load v2)
    SipLoad ecx, edx, 1    ; load v1
    SipMix 17              ; v2 += v1, v1 <<<= 17, v1 ^= v2
    SipStore ebx, eax, 2   ; store (v2 <<< 32)
    SipStore ecx, edx, 1   ; store v1
                           ; .
    SipLoad eax, ebx, 0    ; load v0
    SipLoad ecx, edx, 3    ; load v3
    SipMix 21              ; v0 += v3, v3 <<<= 21, v3 ^= v0
    SipStore eax, ebx, 0   ; store v0
    SipStore ecx, edx, 3   ; store v3
%endmacro

;;
;; siphash_step_mem64
;;
;; Add 64 bit word into the hash.
;;
;; preconditions:  EBP = address where the SipHash state is stored
;;                 ESI = address of input data
;;
;; preserves:      ESI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EDI, EFLAGS
;;
siphash_step_mem64:
    SipLoad eax, ebx, 3
    xor eax, dword [esi]
    xor ebx, dword [esi + 4]
    SipStore eax, ebx, 3
  %rep SipHashC
    SipRound
  %endrep
    SipLoad eax, ebx, 0
    xor eax, dword [esi]
    xor ebx, dword [esi + 4]
    SipStore eax, ebx, 0
    ret

;;
;; siphash_step_reg32
;;
;; Add 32 bit word (zero-extended to 64 bits) into the hash.
;;
;; preconditions:  EBP = address where the SipHash state is stored
;;                 ESI = input word
;;
;; preserves:      ESI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EDI, EFLAGS
;;
siphash_step_reg32:
    xor dword SipStateLo(3), esi
  %rep SipHashC
    SipRound
  %endrep
    xor dword SipStateLo(0), esi
    ret

;;
;; siphash_init (native procedure)
;;
;; Initialize SipHash internal state using a 128-bit key.
;;
;; preconditions:  ESI = address of the key (16 bytes)
;;                 EBP = address of SipHash internal state (32 bytes)
;;
;; postconditions: [EBP + k], k = 0...31, initialized
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    1 dword (incl. call/ret)
;;
siphash_init:
    mov eax, [esi]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    mov edx, [esi + 12]
    xor eax, 0x70736575
    xor ebx, 0x736f6d65
    xor ecx, 0x6e646f6d
    xor edx, 0x646f7261
    SipStore eax, ebx, 0  ; initialize v0
    SipStore ecx, edx, 1  ; initialize v1
    mov eax, [esi]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    mov edx, [esi + 12]
    xor eax, 0x6e657261
    xor ebx, 0x6c796765
    xor ecx, 0x79746573
    xor edx, 0x74656462
    SipStore eax, ebx, 2  ; initialize v2
    SipStore ecx, edx, 3  ; initialize v3
    ret

;;
;; siphash_finish (native procedure)
;;
;; Complete SipHash and extract the hash from the internal state.
;;
;; preconditions:  EBP = address of SipHash internal state (32 bytes)
;;
;; postconditions: EBX:EAX = 64-bit hash
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;; stack usage:    1 dword (incl. call/ret)
;;
siphash_finish:
    xor dword SipStateLo(2), 0xFF
  %rep SipHashD
    SipRound
  %endrep
    ;; extract final value
    SipLoad eax, ebx, 0
    SipLoad ecx, edx, 1
    xor eax, ecx
    xor ebx, edx
    SipLoad ecx, edx, 2
    xor eax, ecx
    xor ebx, edx
    SipLoad ecx, edx, 3
    xor eax, ecx
    xor ebx, edx
    ret
