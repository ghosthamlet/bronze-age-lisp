%include "macros.inc"
%include "testenv.asm"
%include "unicode/generated-data.asm"
%include "unicode/generated-code.asm"
%include "unicode/unicode-lookup.asm"

%macro check_alphabetic 2
    mov eax, %1
    call alphabetic_code
    cmp al, %2
    call pass_if.z
%endmacro

    align 4
_start:
    check_alphabetic 0, 0
    check_alphabetic 13, 0
    check_alphabetic 10, 0
    call next_subtest
    check_alphabetic ('A' - 1), 0
    check_alphabetic 'A', 1
    check_alphabetic 'B', 1
    check_alphabetic 'M', 1
    check_alphabetic 'Z', 1
    check_alphabetic ('Z' + 1), 0
    call next_subtest
    check_alphabetic ('a' - 1), 0
    check_alphabetic 'a', 1
    check_alphabetic 'b', 1
    check_alphabetic 'p', 1
    check_alphabetic 'z', 1
    check_alphabetic ('z' + 1), 0
    call next_subtest
    check_alphabetic 0xB4, 0
    check_alphabetic 0xB5, 1
    check_alphabetic 0xB6, 0
    check_alphabetic 0xBF, 0
    check_alphabetic 0xC0, 1
    check_alphabetic 0xF6, 1
    check_alphabetic 0xF7, 0
    check_alphabetic 0xF8, 1
    call next_subtest
    check_alphabetic 0x3040, 0
    check_alphabetic 0x3041, 1
    check_alphabetic 0x3104, 0
    check_alphabetic 0x3105, 1
    check_alphabetic 0x850F, 1
    call next_subtest
    check_alphabetic 0x103A0, 1
    check_alphabetic 0x103CF, 1
    check_alphabetic 0x103D0, 0
    check_alphabetic 0x103D1, 1
    check_alphabetic 0x1D454, 1
    check_alphabetic 0x1D455, 0
    check_alphabetic 0x1D456, 1
    check_alphabetic 0x1D7CE, 0
    jmp test_finished
