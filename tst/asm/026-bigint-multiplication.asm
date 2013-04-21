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
    call fail
    jmp rn_fatal
rn_backup_cc:
rn_restore_cc:
    ret

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
    call test_umul_0
    call test_umul_1
    call test_umul_2
    call test_imul_1
    call test_imul_2
    call test_shift
    call test_bb_1
    call test_bb_2
    call test_bb_3
    jmp test_finished

%macro check_umul 3
    mov ebx, %1
    mov esi, %2
    mov edi, 0x12345678
    mov ebp, 0x56789ABC
    call rn_bigint_umul
    test al, 3
    call pass_if.z
    cmp [eax], byte bigint_header(0)
    call pass_if.z
    cmp edi, 0x12345678
    call pass_if.z
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %3
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

%macro check_imul 3
    mov ebx, %1
    mov ecx, %2
    mov esi, 0xDEF01234
    mov edi, 0x12345678
    mov ebp, 0x56789ABC
    call rn_bigint_times_fixint
    cmp esi, 0xDEF01234
    call pass_if.z
    cmp edi, 0x12345678
    call pass_if.z
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %3
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

%macro check_shl30 2
    mov ebx, %1
    mov esi, 0xDEF01234
    mov edi, 0x12345678
    mov ebp, 0x56789ABC
    call rn_integer_shl_30
    mov ecx, %1
    cmp ebx, ecx
    call pass_if.z
    cmp esi, 0xDEF01234
    call pass_if.z
    cmp edi, 0x12345678
    call pass_if.z
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %2
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

%macro check_bb 3
    mov ebx, %1
    mov ecx, %2
    mov esi, 0xDEF01234
    mov edi, 0x12345678
    mov ebp, 0x56789ABC
    call rn_bigint_times_bigint
    cmp esi, 0xDEF01234
    call pass_if.z
    cmp edi, 0x12345678
    call pass_if.z
    cmp ebp, 0x56789ABC
    call pass_if.z
    mov ebx, eax
    mov ecx, %3
    call rn_integer_compare
    test eax, eax
    call pass_if.z
%endmacro

test_umul_0:
    mov ebx, 0
    mov esi, bigint_2p29
    call rn_bigint_umul
    cmp eax, fixint_value(0)
    call pass_if.z
    ret

test_umul_1:
    check_umul 1, bigint_2p29, bigint_2p29
    check_umul 2, bigint_2p29, bigint_2p30
    check_umul 2, bigint_2p30, bigint_2p31
    check_umul 4, bigint_2p29, bigint_2p31
    check_umul 6, bigint_2p29, bigint_2p30_2p31
    ret

test_umul_2:
    call next_subtest
    check_umul 42, bigint_123412341234, bigint_5183318331828
    check_umul 42, bigint_123412341234p30, bigint_5183318331828p30
    check_umul 20, bigint_m98765432198765, bigint_m1975308643975300
    check_umul 1073649841, bigint_m1975308643975300, bigint_m2120789811530006452927300
    ret

test_imul_1:
    call next_subtest
    check_imul bigint_123412341234, fixint_value(0), fixint_value(0)
    check_imul bigint_123412341234, fixint_value(1), bigint_123412341234
    check_imul bigint_98765432198765, fixint_value(-1), bigint_m98765432198765
    check_imul bigint_m98765432198765, fixint_value(-1), bigint_98765432198765
    ret

test_imul_2:
    call next_subtest
    check_imul bigint_m98765432198765, fixint_value(20), bigint_m1975308643975300
    check_imul bigint_98765432198765, fixint_value(-20), bigint_m1975308643975300
    ret

test_shift:
    call next_subtest
    check_shl30 fixint_value(1), bigint_2p30
    check_shl30 bigint_123412341234, bigint_123412341234p30
    check_shl30 bigint_123412341234p30, bigint_123412341234p60
    ret

test_bb_1:
    call next_subtest
    check_bb bigint_2p29, bigint_2p29, bigint_2p58
    check_bb bigint_2p29, bigint_2p31, bigint_2p60
    check_bb bigint_2p31, bigint_2p29, bigint_2p60
    check_bb bigint_1234567890, bigint_2345678901, bigint_2895899851425088890
    check_bb bigint_2895899851425088890, bigint_2895899851425088890, bigint_8386235949483851907606211344401432100
    ret

test_bb_2:
    call next_subtest
    check_bb bigint_m98765432198765, bigint_m1975308643975300, bigint_195092211948176924449350504500
    ret

test_bb_3:
    call next_subtest
    check_bb bigint_long_1, bigint_2p60, bigint_long_2
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

bigint_123412341234:
    dd bigint_header(4)
    dd fixint_value(1005773298)
    dd fixint_value(114)
    dd fixint_value(0)

bigint_123412341234p30:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(1005773298)
    dd fixint_value(114)

bigint_123412341234p60:
    dd bigint_header(6)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(1005773298)
    dd fixint_value(114)
    dd fixint_value(0)

bigint_5183318331828:
    dd bigint_header(4)
    dd fixint_value(366547380)
    dd fixint_value(4827)
    dd fixint_value(0)

bigint_5183318331828p30:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(366547380)
    dd fixint_value(4827)

bigint_98765432198765:
    dd bigint_header(4)
    dd fixint_value(511743597)
    dd fixint_value(91982)
    dd fixint_value(0)

bigint_m98765432198765:
    dd bigint_header(4)
    dd fixint_value(561998227)
    dd fixint_value(-91983)
    dd fixint_value(-1)

bigint_m1975308643975300:
    dd bigint_header(4)
    dd fixint_value(502546300)
    dd fixint_value(-1839650)
    dd fixint_value(-1)

bigint_1234567890:
    dd bigint_header(4)
    dd fixint_value(160826066)
    dd fixint_value(1)
    dd fixint_value(0)

bigint_2345678901:
    dd bigint_header(4)
    dd fixint_value(198195253)
    dd fixint_value(2)
    dd fixint_value(0)

bigint_2895899851425088890:
    dd bigint_header(4)
    dd fixint_value(491554170)
    dd fixint_value(549533257)
    dd fixint_value(2)

bigint_8386235949483851907606211344401432100:
    dd bigint_header(6)
    dd fixint_value(705166884)
    dd fixint_value(223431688)
    dd fixint_value(952394604)
    dd fixint_value(331896506)
    dd fixint_value(6)

bigint_195092211948176924449350504500:
    dd bigint_header(6)
    dd fixint_value(466505780)
    dd fixint_value(400210953)
    dd fixint_value(638053655)
    dd fixint_value(157)
    dd fixint_value(0)

bigint_2120789811530006452927300:
    dd bigint_header(4)
    dd fixint_value(57047876)
    dd fixint_value(1005920817)
    dd fixint_value(1839491)

bigint_m2120789811530006452927300:
    dd bigint_header(4)
    dd fixint_value(1016693948)
    dd fixint_value(67821006)
    dd fixint_value(1071902332)

bigint_long_1:
    dd bigint_header(62)
    times 58 dd fixint_value(1)
    dd fixint_value(1)
    dd fixint_value(0)
    dd fixint_value(0)

bigint_long_2:
    dd bigint_header(62)
    dd fixint_value(0)
    dd fixint_value(0)
    times 58 dd fixint_value(1)
    dd fixint_value(1)

lisp_rom_limit:
