%include "macros.inc"
%include "testenv.asm"
%include "runtime/continuation-ancestry.asm"

%macro check_desc 3
    mov eax, %1
    mov ebx, %2
    call rn_descendantP_procz
    call pass_if.%3
%endmacro

%macro check_ancestor 3
    mov eax, %1
    mov ebx, %2
    mov ecx, 0x1234ABCD
    mov edx, 0x2345BCDE
    mov esi, 0x3456CDEF
    mov edi, 0x4567DEFA
    mov ebp, 0x5678EFAB
    call rn_common_ancestor
    cmp eax, %3
    call pass_if.z
    cmp ebx, %3
    call pass_if.z
    cmp ecx, 0x1234ABCD
    call pass_if.z
    cmp edx, 0x2345BCDE
    call pass_if.z
    cmp esi, 0x3456CDEF
    call pass_if.z
    cmp edi, 0x4567DEFA
    call pass_if.z
    cmp ebp, 0x5678EFAB
    call pass_if.z
%endmacro

    align 4
_start:
    call test_descendantP
    call test_common_ancestor
    jmp test_finished

test_descendantP:
    call next_subtest
    check_desc cR, cR, z
    check_desc cA, cA, z
    check_desc cA, cR, z
    check_desc cR, cA, nz
    check_desc cA, cB, nz
    check_desc cB, cA, nz
    call next_subtest
    check_desc cF, cR, z
    check_desc cR, cF, nz
    check_desc cF, cB, nz
    check_desc cB, cF, nz
    ret

test_common_ancestor:
    call next_subtest
    check_ancestor cR, cR, cR
    check_ancestor cA, cR, cR
    check_ancestor cR, cA, cR
    check_ancestor cA, cA, cA
    call next_subtest
    check_ancestor cA, cB, cR
    check_ancestor cB, cA, cR
    check_ancestor cA, cC, cR
    check_ancestor cC, cA, cR
    check_ancestor cB, cC, cB
    check_ancestor cC, cB, cB
    call next_subtest
    check_ancestor cE, cF, cD
    check_ancestor cF, cE, cD
    check_ancestor cF, cA, cR
    check_ancestor cF, cC, cR
    ret

section .lisp_rom

%macro cont 1
    dd cont_header(4)
    dd 0xDEADBEEF
    dd %1
    dd 0xDEADCAFE
%endmacro

;;
;;   R
;;   |
;;   +----+----+
;;   |    |    |
;;   A    B    D
;;        |    |
;;        C    +----+
;;             |    |
;;             E    F
;;

    align 8
lisp_rom_base:
cR: cont inert_tag
cA: cont cR
cB: cont cR
cC: cont cB
cD: cont cR
cE: cont cD
cF: cont cD
