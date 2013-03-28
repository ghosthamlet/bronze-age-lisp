%include "macros.inc"
%include "testenv.asm"
%include "unicode/generated-data.asm"
%include "unicode/generated-code.asm"
%include "unicode/unicode-lookup.asm"

%macro check_white_space 2
    mov eax, %1
    call white_space_code
    cmp al, %2
    call pass_if.z
%endmacro

    align 4
_start:
    check_white_space 0x08, 0
    check_white_space 0x09, 1
    check_white_space 0x0A, 1
    check_white_space 0x0B, 1
    check_white_space 0x0C, 1
    check_white_space 0x0D, 1
    check_white_space 0x0E, 0
    check_white_space 0x1B, 0
    check_white_space 0x1F, 0
    check_white_space 0x20, 1
    check_white_space 0x21, 0
    call next_subtest
    check_white_space 0x84, 0
    check_white_space 0x85, 1
    check_white_space 0x86, 0
    jmp test_finished
