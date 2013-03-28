;;;
;;; utf8.asm
;;;
;;; UTF-8 encoding.
;;;

;;
;; rn_encode_utf8 (native procedure)
;;
;; Stores one UTF-8 character in a buffer.
;;
;; preconditions:  EAX = char (tagged value)
;;                 EBX = buffer
;; postconditions: ECX = byte count
;;                 UTF-8 sequence stored in the buffer
;; preserves:      EAX, EBX, EDX, ESI, EDI, EBP
;; clobbers:       ECX
;;
rn_encode_utf8:
    test eax, ~0x7FFF
    mov ecx, 1
    jnz .nonascii
    mov [ebx], ah
    ret
  .nonascii:
    push eax
    push edx
    xor ecx, ecx
    shr eax, 8
    test eax, 0xFFFFF800
    jz .cont_1
    test eax, 0xFFFF0000
    jz .cont_2
    test eax, 0xFFE00000
    jz .cont_3
%assign n 4
%rep 4
  .cont_ %+ n:
    mov dl, al
    and dl, 0x3F
    or  dl, 0x80
    shr eax, 6
    mov [ebx + n], dl
    inc cl
%assign n n-1
%endrep
    mov dl, 0x80
    sar dl, cl
    or al, dl
    inc cl
    mov [ebx], al
    pop edx
    pop eax
    ret

;;
;; rn_decode_utf8 (native procedure)
;;
;; Processes one byte of UTF-8 input. See utf8-dfa.asm.
;;
;; preconditions:  EAX = input byte (untagged integer 0-255)
;;                 EBX = DFA state (untagged integer 0-255)
;;                       UTF8_ACCEPT is the start state
;;                 ECX = codepoint accumulator (untagged integer)
;;                 utf8d contains the DFA transition table
;;
;; postconditions: EBX = new DFA state
;;                     = UTF8_ACCEPT, if a character was produced
;;                     = UTF8_REJECT, if the input is not valid
;;                 ECX = codepoint accumulator
;;                     = code point if a character was produced
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX
;;
rn_decode_utf8:
    movzx edx, byte [utf8d + eax]
    test ebx, ebx
    jnz .continuation_byte
  .start:
    movzx ebx, byte [utf8d + 256 + ebx + edx]
    mov cl, dl
    mov edx, 0xFF
    shr dl, cl
    and dl, al
    movzx ecx, dl
    ret
  .continuation_byte:
    shl ecx, 6
    and al, 0x3F
    or cl, al
    movzx ebx, byte [utf8d + 256 + ebx + edx]
    ret
