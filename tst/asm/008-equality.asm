%include "macros.inc"
%include "testenv.asm"
%include "runtime/list-metrics.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0300
err_out_of_blob_memory          equ 0xDEAD0400
err_internal_error              equ 0xDEAD0500
err_invalid_blob_heap_operation equ 0xDEAD0600
err_not_implemented             equ 0xDEAD0700
private_lookup_table_length     equ 0

program_segment_base:
rn_get_blob_data:
rn_compare_blob_data:
    call fail
    ret
rn_error:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/mark-bits.asm"
%include "runtime/equality.asm"

    align 4
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_fixint
    call test_special
    call test_applicative
    call test_pair
    call test_list
    call test_cycle
    jmp test_finished

%macro check 4
    mov eax, 0x12345678
    mov ebx, %2
    mov ecx, %3
    mov edx, 0x1234ABCD
    mov esi, 0x2345BCDE
    mov edi, 0x4567CDEF
    mov ebp, 0x5678DEFA
    call %1
    cmp eax, %4
    call pass_if.z
    cmp ebx, %2
    call pass_if.z
    cmp ecx, %3
    call pass_if.z
    cmp edx, 0x1234ABCD
    call pass_if.z
    cmp esi, 0x2345BCDE
    call pass_if.z
    cmp edi, 0x4567CDEF
    call pass_if.z
    cmp ebp, 0x5678DEFA
    call pass_if.z
%endmacro

test_fixint:
    call next_subtest
    check rn_eq,    fixint_value(123), fixint_value(123), 1
    check rn_eq,    fixint_value(123), fixint_value( 42), 0
    check rn_equal, fixint_value(123), fixint_value(123), 1
    check rn_equal, fixint_value(123), fixint_value( 42), 0
    ret

test_special:
    call next_subtest
    check rn_eq,    nil_tag, nil_tag,   1
    check rn_eq,    nil_tag, inert_tag, 0
    check rn_equal, nil_tag, nil_tag,   1
    check rn_equal, nil_tag, inert_tag, 0
    ret

test_applicative:
    call next_subtest
    check rn_eq, applicative_1a, applicative_1a, 1
    check rn_eq, applicative_1b, applicative_1b, 1
    check rn_eq, applicative_1a, applicative_1b, 1
    check rn_eq, applicative_1a, applicative_2,  0
    ret

test_pair:
    call next_subtest
    check rn_eq,    rom_pair_value(pair_1a), rom_pair_value(pair_1a), 1
    check rn_eq,    rom_pair_value(pair_1a), rom_pair_value(pair_1b), 0
    check rn_eq,    rom_pair_value(pair_1a), rom_pair_value(pair_1c), 0
    check rn_equal, rom_pair_value(pair_1a), rom_pair_value(pair_1a), 1
    check rn_equal, rom_pair_value(pair_1a), rom_pair_value(pair_1b), 1
    check rn_equal, rom_pair_value(pair_1a), rom_pair_value(pair_1c), 0
    check rn_equal, rom_pair_value(pair_1b), rom_pair_value(pair_1b), 1
    check rn_equal, rom_pair_value(pair_1b), rom_pair_value(pair_1c), 0
    check rn_equal, rom_pair_value(pair_1c), rom_pair_value(pair_1c), 1
    ret

test_list:
    call next_subtest
    check rn_equal, rom_pair_value(list_1a), rom_pair_value(list_1a), 1
    check rn_equal, rom_pair_value(list_1a), rom_pair_value(list_2a), 0
    check rn_equal, rom_pair_value(list_1a), rom_pair_value(list_1b), 1
    check rn_equal, rom_pair_value(list_1a), rom_pair_value(list_2b), 0
    check rn_equal, rom_pair_value(list_2b), rom_pair_value(list_2a), 1
    ret

test_cycle:
    call next_subtest
    check rn_equal, rom_pair_value(cycle_1a), rom_pair_value(cycle_1a), 1
    check rn_equal, rom_pair_value(cycle_1a), rom_pair_value(cycle_1b), 1
    check rn_equal, rom_pair_value(cycle_1b), rom_pair_value(cycle_1a), 1
    check rn_equal, rom_pair_value(cycle_1a), rom_pair_value(cycle_2a), 0
    check rn_equal, rom_pair_value(cycle_2a), rom_pair_value(cycle_2b), 0
    check rn_equal, rom_pair_value(cycle_2b), rom_pair_value(cycle_2a), 0
    check rn_equal, rom_pair_value(cycle_3a), rom_pair_value(cycle_3b), 1
    check rn_equal, rom_pair_value(cycle_3b), rom_pair_value(cycle_3a), 1
    check rn_equal, rom_pair_value(cycle_2a), rom_pair_value(cycle_3b), 0
    ret

section .lisp_rom
    align 8
lisp_rom_base:

nonpair_object:
    dd environment_header(6)
    dd 0
    dd 0
    dd 0
    dd 0
    dd list_1a + 4

pair_1a:
    dd fixint_value(1)
    dd nil_tag
pair_1b:
    dd fixint_value(1)
    dd nil_tag
pair_1c:
    dd fixint_value(1)
    dd fixint_value(2)

list_1a:
    dd fixint_value(1)
    dd nil_tag
list_2a:
    dd nil_tag
    dd rom_pair_value(list_1a)
list_3a:
    dd boolean_value(1)
    dd rom_pair_value(list_2a)

list_1b:
    dd fixint_value(1)
    dd nil_tag
list_2b:
    dd nil_tag
    dd rom_pair_value(list_1b)
list_3b:
    dd boolean_value(1)
    dd rom_pair_value(list_2b)

cycle_1a:
    dd fixint_value(1)
    dd rom_pair_value(cycle_1a)
cycle_1b:
    dd fixint_value(1)
    dd rom_pair_value(cycle_1b)

cycle_2a:
    dd fixint_value(2)
    dd rom_pair_value(cycle_2b)
cycle_2b:
    dd fixint_value(3)
    dd rom_pair_value(cycle_2a)

cycle_3a:
    dd fixint_value(42)
    dd rom_pair_value(cycle_3b)
cycle_3b:
    dd fixint_value(42)
    dd rom_pair_value(cycle_3a)

applicative_1a:
    dd applicative_header(4)
    dd 0xDEADBEEF
    dd operative_1
    dd 0
applicative_1b:
    dd applicative_header(4)
    dd 0xDEADBEEF
    dd operative_1
    dd 0
applicative_2:
    dd applicative_header(4)
    dd 0xDEADBEEF
    dd operative_2
    dd 0

operative_1:
    dd operative_header(1)
    dd 0
operative_2:
    dd operative_header(1)
    dd 0

lisp_rom_limit: