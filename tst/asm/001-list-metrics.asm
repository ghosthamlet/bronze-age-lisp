%include "macros.inc"
%include "testenv.asm"
%include "runtime/list-metrics.asm"

%define fake_mutable_pair(x) ((absolute_rom_address(x) >> 1) | 0x80000003)

    align 4
_start:
    call test_nonpair
    call test_nil
    call test_finite
    call test_improper
    call test_cycle
    call test_prefix
    call test_long

    jmp test_finished

%macro invoke 1
    call next_subtest
    mov esi, 0x1234ABCD
    mov edi, 0x2345BCDE
    mov ebp, 0x4567CDEF
    mov ebx, %1
    call rn_list_metrics
%endmacro

%macro invoke_immutable 1
    call next_subtest
    mov esi, 0x1234ABCD
    mov edi, 0x2345BCDE
    mov ebp, 0x4567CDEF
    load_immutable_pair ebx, %1
    call rn_list_metrics
%endmacro

%macro invoke_mutable 1
    call next_subtest
    mov esi, 0x1234ABCD
    mov edi, 0x2345BCDE
    mov ebp, 0x4567CDEF
    load_mutable_pair ebx, %1
    call rn_list_metrics
%endmacro

%macro check 4
    cmp eax, %1
    call pass_if.z
    cmp ebx, %2
    call pass_if.z
    cmp ecx, %3
    call pass_if.z
    cmp edx, %4
    call pass_if.z
    cmp esi, 0x1234ABCD
    call pass_if.z
    cmp edi, 0x2345BCDE
    call pass_if.z
    cmp ebp, 0x4567CDEF
    call pass_if.z
%endmacro

test_nonpair:
    invoke fixint_value(123)
    check 0, fixint_value(123), 0, 0
    invoke nonpair_object
    check 0, nonpair_object, 0, 0
    ret

test_nil:
    invoke nil_tag
    check 1, nil_tag, 0, 0
    ret

test_finite:
    invoke_immutable list_1
    check 1, rom_pair_value(list_1), 0, 1
    invoke_mutable list_2
    check 1, fake_mutable_pair(list_2), 0, 2
    invoke_immutable list_3
    check 1, rom_pair_value(list_3), 0, 3
    ret

test_improper:
    invoke_immutable improper_1a
    check 0, rom_pair_value(improper_1a), 0, 1
    invoke_mutable improper_1b
    check 0, fake_mutable_pair(improper_1b), 0, 1
    invoke rom_pair_value(improper_2)
    check 0, rom_pair_value(improper_2), 0, 2
    invoke fake_mutable_pair(improper_3)
    check 0, fake_mutable_pair(improper_3), 0, 3
    ret

test_cycle:
    invoke_immutable cycle_1
    check 1, rom_pair_value(cycle_1), 1, 1
    invoke_immutable cycle_2a
    check 1, rom_pair_value(cycle_2a), 2, 2
    invoke_immutable cycle_3a
    check 1, rom_pair_value(cycle_3a), 3, 3
    ret

test_prefix:
    invoke_immutable prefix_1_1
    check 1, rom_pair_value(cycle_1), 1, 2
    invoke_immutable prefix_2_1
    check 1, rom_pair_value(cycle_1), 1, 3
    invoke_immutable prefix_3_1
    check 1, rom_pair_value(cycle_1), 1, 4

    invoke_immutable prefix_1_2
    check 1, rom_pair_value(cycle_2b), 2, 3
    invoke_immutable prefix_2_2
    check 1, rom_pair_value(cycle_2b), 2, 4
    invoke_immutable prefix_3_2
    check 1, rom_pair_value(cycle_2b), 2, 5
    ret

test_long:
    invoke rom_pair_value(long_acyclic_37)
    check 1, rom_pair_value(long_acyclic_37), 0, 37
    invoke rom_pair_value(long_cyclic_1_49)
    check 1, rom_pair_value(cycle_1), 1, 50
    invoke rom_pair_value(long_cyclic_3_13)
    check 1, rom_pair_value(cycle_3c), 3, 16
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
    dd list_1 + 4
list_1:
    dd fixint_value(1)
    dd nil_tag
list_2:
    dd nil_tag
    dd rom_pair_value(list_1)
list_3:
    dd boolean_value(1)
    dd rom_pair_value(list_2)
improper_1a:
    dd boolean_value(1)
    dd fixint_value(5)
improper_1b:
    dd boolean_value(1)
    dd nonpair_object
improper_2:
    dd boolean_value(0)
    dd rom_pair_value(improper_1a)
improper_3:
    dd boolean_value(0)
    dd rom_pair_value(improper_2)

cycle_1:
    dd fixint_value(1)
    dd rom_pair_value(cycle_1)

cycle_2a:
    dd fixint_value(2)
    dd rom_pair_value(cycle_2b)
cycle_2b:
    dd fixint_value(3)
    dd rom_pair_value(cycle_2a)

cycle_3a:
    dd fixint_value(4)
    dd rom_pair_value(cycle_3b)
cycle_3b:
    dd fixint_value(5)
    dd rom_pair_value(cycle_3c)
cycle_3c:
    dd fixint_value(6)
    dd rom_pair_value(cycle_3a)

prefix_1_1:
    dd fixint_value(100)
    dd rom_pair_value(cycle_1)
prefix_2_1:
    dd fixint_value(100)
    dd rom_pair_value(prefix_1_1)
prefix_3_1:
    dd fixint_value(100)
    dd rom_pair_value(prefix_2_1)

prefix_1_2:
    dd fixint_value(100)
    dd rom_pair_value(cycle_2b)
prefix_2_2:
    dd fixint_value(100)
    dd rom_pair_value(prefix_1_2)
prefix_3_2:
    dd fixint_value(100)
    dd rom_pair_value(prefix_2_2)

%macro def_long 3
    %assign i %2
    %rep (%2 - 1)
  long_%1_ %+ i:
    %assign i (i - 1)
    dd fixint_value(i)
    dd rom_pair_value(long_%1_ %+ i)
    %endrep
  long_%1_1:
    dd fixint_value(0)
    dd %3
%endmacro

def_long acyclic, 37, nil_tag
def_long cyclic_1, 49, rom_pair_value(cycle_1)
def_long cyclic_3, 13, rom_pair_value(cycle_3c)
