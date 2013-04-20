%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory      equ 0xDEAD0010
err_internal_error          equ 0xDEAD0020
err_not_a_number            equ 0xDEAD0030
err_not_implemented         equ 0xDEAD0040
private_lookup_table_length equ 0

rn_get_blob_data:
    call fail
    ret
rn_error:
    call fail
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/list-metrics.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/bigints.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_shr_0
    call test_shr_1
    call test_shr_2
    call test_shr_3
    call test_shl_0
    call test_shl_1
    call test_shl_2
    jmp test_finished

%macro check_shr 3
    mov ebx, %1
    mov ecx, %2
    mov ebp, 0x56789ABC
    call rn_bigint_shift_right
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %3
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

%macro check_shl 3
    mov ebx, %1
    mov ecx, %2
    mov ebp, 0x56789ABC
    call rn_bigint_shift_left
    mov edx, %3
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %3
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

test_shr_0:
    check_shr bigint_2p120, 0, bigint_2p120,
    check_shr bigint_m98765432198765, 0, bigint_m98765432198765,
    ret

test_shr_1:
    check_shr bigint_2p29, 300, fixint_value(0)
    check_shr bigint_m98765432198765, 200, fixint_value(-1)
    ret

test_shr_2:
    check_shr bigint_2p29, 30, fixint_value(0)
    check_shr bigint_2p29, 29, fixint_value(1)
    check_shr bigint_m98765432198765, 64, fixint_value(-1)
    ret

test_shr_3:
    check_shr bigint_2p30, 1, bigint_2p29
    check_shr bigint_2p60, 1, bigint_2p59
    check_shr bigint_2p60, 2, bigint_2p58
    check_shr bigint_2p30_2p31, 1, bigint_2p29_2p30
    check_shr bigint_2p90, 30, bigint_2p60
    check_shr bigint_2p90, 31, bigint_2p59
    check_shr bigint_2p90, 32, bigint_2p58
    check_shr bigint_2p90, 60, bigint_2p30
    check_shr bigint_2p90, 61, bigint_2p29
    check_shr bigint_2p120, 30, bigint_2p90
    check_shr bigint_2p120, 60, bigint_2p60
    check_shr bigint_2p120, 90, bigint_2p30
    ret

test_shl_0:
    check_shl bigint_2p120, 0, bigint_2p120,
    check_shl bigint_m98765432198765, 0, bigint_m98765432198765,
    ret

test_shl_1:
    check_shl bigint_2p29, 1, bigint_2p30
    check_shl bigint_2p29, 2, bigint_2p31
    ret

test_shl_2:
    check_shl bigint_2p29_2p30, 1, bigint_2p30_2p31
    check_shl bigint_2p30, 30, bigint_2p60
    check_shl bigint_2p30, 60, bigint_2p90
    check_shl bigint_2p30, 90, bigint_2p120
    ret

section .lisp_rom
    align 8
lisp_rom_base:

bigint_2p29:
    dd bigint_header(4)
    dd fixint_value(min_fixint)
    dd fixint_value(0)
    dd fixint_value(0)

bigint_2p30:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(1)
    dd fixint_value(0)

bigint_2p31:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(2)
    dd fixint_value(0)

bigint_2p30_2p31:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(3)
    dd fixint_value(0)

bigint_2p29_2p30:
    dd bigint_header(4)
    dd fixint_value(min_fixint)
    dd fixint_value(1)
    dd fixint_value(0)

bigint_2p58:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(1 << 28)
    dd fixint_value(0)

bigint_2p59:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(1 << 29)
    dd fixint_value(0)

bigint_2p60:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(1)

bigint_2p90:
    dd bigint_header(6)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(1)
    dd fixint_value(0)

bigint_2p120:
    dd bigint_header(6)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(1)

bigint_m98765432198765:
    dd bigint_header(4)
    dd fixint_value(561998227)
    dd fixint_value(-91983)
    dd fixint_value(-1)

lisp_rom_limit:
