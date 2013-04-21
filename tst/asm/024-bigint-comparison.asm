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
rn_out_of_memory:
rn_error:
rn_backup_cc:
rn_restore_cc:
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
    call test_siglog_nan
    call test_siglog_fixint
    call test_siglog_bigint
    call test_compare_fixint
    call test_compare_bigint
    call test_compare_mix
    jmp test_finished

%macro check_siglog_ni 1
    mov ebx, %1
    call rn_siglog
    call pass_if.nz
%endmacro

%macro check_siglog_i 2
    mov ebx, %1
    call rn_siglog
    call pass_if.z
    cmp eax, %2
    call pass_if.z
    mov ebx, eax
    neg ebx
%endmacro

%macro check_eq 2
    mov ebx, %1
    mov ecx, %2
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

%macro check_lt 2
    mov ebx, %1
    mov ecx, %2
    call rn_integer_compare
    cmp eax, 0
    call pass_if.l
%endmacro

%macro check_gt 2
    mov ebx, %1
    mov ecx, %2
    call rn_integer_compare
    cmp eax, 0
    call pass_if.g
%endmacro

test_siglog_nan:
    check_siglog_ni nil_tag
    check_siglog_ni boolean_value(0)
    check_siglog_ni rom_pair_value(dummy_obj)
    check_siglog_ni dummy_obj
    ret

test_siglog_fixint:
    call next_subtest
    check_siglog_i fixint_value(min_fixint),     -1
    check_siglog_i fixint_value(min_fixint + 1), -1
    check_siglog_i fixint_value(-2),             -1
    check_siglog_i fixint_value(-1),             -1
    check_siglog_i fixint_value(0),               0
    check_siglog_i fixint_value(1),               1
    check_siglog_i fixint_value(2),               1
    check_siglog_i fixint_value(max_fixint - 1),  1
    check_siglog_i fixint_value(max_fixint),      1
    ret

test_siglog_bigint:
    call next_subtest
    check_siglog_i bigint_pos_4a, 3
    check_siglog_i bigint_pos_4b, 3
    check_siglog_i bigint_pos_4c, 3
    check_siglog_i bigint_pos_6,  5
    check_siglog_i bigint_pos_8,  7
    check_siglog_i bigint_neg_4a, -3
    check_siglog_i bigint_neg_4b, -3
    check_siglog_i bigint_neg_4c, -3
    check_siglog_i bigint_neg_6,  -5
    check_siglog_i bigint_neg_10, -9
    ret

test_compare_fixint:
    call next_subtest
    check_eq fixint_value(0), fixint_value(0)
    check_eq fixint_value(1), fixint_value(1)
    check_eq fixint_value(-1), fixint_value(-1)
    check_eq fixint_value(min_fixint), fixint_value(min_fixint)
    check_eq fixint_value(max_fixint), fixint_value(max_fixint)

    check_lt fixint_value(0), fixint_value(1)
    check_lt fixint_value(1), fixint_value(max_fixint)
    check_lt fixint_value(-1), fixint_value(0)
    check_lt fixint_value(min_fixint), fixint_value(-1)
    check_lt fixint_value(min_fixint), fixint_value(max_fixint)

    check_gt fixint_value(0), fixint_value(-1)
    check_gt fixint_value(1), fixint_value(0)
    check_gt fixint_value(-1), fixint_value(min_fixint)
    check_gt fixint_value(max_fixint), fixint_value(1)
    check_gt fixint_value(max_fixint), fixint_value(min_fixint)
    ret

test_compare_bigint:
    call next_subtest
    check_eq bigint_pos_4a, bigint_pos_4a
    check_gt bigint_pos_4a, bigint_pos_4b
    check_lt bigint_pos_4a, bigint_pos_6
    check_gt bigint_pos_4a, bigint_neg_4a
    check_lt bigint_neg_10, bigint_pos_6
    check_gt bigint_601_000_000, bigint_600_000_000
    check_lt bigint_600_000_000, bigint_601_000_000
    check_lt bigint_10000000000, bigint_10600228229
    ret

test_compare_mix:
    call next_subtest
    check_gt bigint_pos_4a, fixint_value(0)
    check_gt bigint_pos_4a, fixint_value(max_fixint)
    check_gt bigint_pos_4a, fixint_value(min_fixint)
    check_gt bigint_pos_6,  fixint_value(-1)
    check_lt bigint_neg_4a, fixint_value(0)
    check_lt bigint_neg_4a, fixint_value(min_fixint)
    check_lt bigint_neg_4a, fixint_value(max_fixint)
    check_lt bigint_neg_4a, fixint_value(-1)
    ret

section .lisp_rom
    align 8
lisp_rom_base:

dummy_obj:
    dd 0xDEADBEEF
    dd 0xDEADBEEF

bigint_pos_4a:
    dd bigint_header(4)
    dd fixint_value(-1)
    dd fixint_value(-1)
    dd fixint_value(max_fixint)

bigint_pos_4b:
    dd bigint_header(4)
    dd fixint_value(min_fixint)
    dd fixint_value(min_fixint)
    dd fixint_value(max_fixint - 1)

bigint_pos_4c:
    dd bigint_header(4)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)

bigint_pos_6:
    dd bigint_header(6)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)

bigint_pos_8:
    dd bigint_header(8)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(1)

bigint_neg_4a:
    dd bigint_header(4)
    dd fixint_value(-1)
    dd fixint_value(0)
    dd fixint_value(-1)

bigint_neg_4b:
    dd bigint_header(4)
    dd fixint_value(-1)
    dd fixint_value(-1)
    dd fixint_value(min_fixint)

bigint_neg_4c:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(min_fixint + 1)

bigint_neg_6:
    dd bigint_header(6)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(min_fixint)
    dd fixint_value(-1)
    dd fixint_value(-1)

bigint_neg_10:
    dd bigint_header(10)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(1234)
    dd fixint_value(0)
    dd fixint_value(-1)
    dd fixint_value(0)
    dd fixint_value(min_fixint)
    dd fixint_value(0)
    dd fixint_value(min_fixint)

bigint_600_000_000:
    dd bigint_header(4)
    dd 0x8F0D1801
    dd 0x00000001
    dd 0x00000001

bigint_601_000_000:
    dd bigint_header(4)
    dd 0x8F4A2101
    dd 0x00000001
    dd 0x00000001

bigint_10600228229:
    dd bigint_header(4)
    dd fixint_value(936551813)
    dd fixint_value(9)
    dd fixint_value(0)

bigint_10000000000:
    dd bigint_header(4)
    dd fixint_value(336323584)
    dd fixint_value(9)
    dd fixint_value(0)

lisp_rom_limit:
