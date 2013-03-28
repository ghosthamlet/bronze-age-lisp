%include "macros.inc"
%include "testenv.asm"
%include "runtime/utf8-dfa.asm"
%include "runtime/utf8.asm"

%macro check_enc 3-*
    mov eax, %1
    mov ebx, test_buffer
    call rn_encode_utf8
    cmp eax, %1
    call pass_if.z
    cmp ebx, test_buffer
    call pass_if.z
    cmp ecx, %2
    call pass_if.z
    %assign i 0
  %rep %2
    cmp [test_buffer + i], byte %3
    call pass_if.z
    %assign i (i + 1)
    %rotate 1
  %endrep
%endmacro

    align 4
_start:
    call test_encoder
    ; TODO call test_decoder
    jmp test_finished

test_encoder:
    check_enc char_value(0x20), 1, 0x20
    check_enc char_value(0x00), 1, 0x00
    check_enc char_value('z'),  1, 'z'
    check_enc char_value(0x7F), 1, 0x7F
    call next_subtest
    check_enc char_value(0x80), 2, 0xC2, 0x80
    check_enc char_value(0x016E), 2, 0xC5, 0xAE
    check_enc char_value(0x03BB), 2, 0xCE, 0xBB
    check_enc char_value(0x07FF), 2, 0xDF, 0xBF
    call next_subtest
    check_enc char_value(0x0900), 3, 0xE0, 0xA4, 0x80
    check_enc char_value(0x2213), 3, 0xE2, 0x88, 0x93
    check_enc char_value(0x3005), 3, 0xE3, 0x80, 0x85
    check_enc char_value(0xFFFD), 3, 0xEF, 0xBF, 0xBD
    call next_subtest
    check_enc char_value(0x10000), 4, 0xF0, 0x90, 0x80, 0x80
    check_enc char_value(0x1D11E), 4, 0xF0, 0x9D, 0x84, 0x9E
    check_enc char_value(0x100000), 4, 0xF4, 0x80, 0x80, 0x80
    check_enc char_value(0x10FFFD), 4, 0xF4, 0x8F, 0xBF, 0xBD
    ret
