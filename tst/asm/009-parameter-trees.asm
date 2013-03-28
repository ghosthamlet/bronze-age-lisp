%include "macros.inc"
%include "testenv.asm"
%include "runtime/list-metrics.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0300
err_out_of_blob_memory          equ 0xDEAD0400
err_internal_error              equ 0xDEAD0500
err_invalid_blob_heap_operation equ 0xDEAD0600
err_not_implemented             equ 0xDEAD0700
err_repeated_symbol             equ 0xDEAD0800
err_invalid_ptree               equ 0xDEAD0900
err_cyclic_ptree                equ 0xDEAD0A00
err_immutable_environment       equ 0xDEAD0B00
err_invalid_argument            equ 0xDEAD0C00
err_undefined_private_binding   equ 0xDEAD0D00

private_lookup_table_length     equ 0
ground_lookup_table_length      equ 0

program_segment_base:
rn_get_blob_data:
    call fail
    ret
rn_error:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/environment-lookup.asm"
%include "runtime/environment-mutations.asm"
%include "runtime/mark-bits.asm"
%include "runtime/parameter-trees.asm"

    align 4
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_validity_check_1
    call test_validity_check_2
    call test_match_1
    jmp test_finished

%macro t_check 3
    mov eax, 0x12345678
    mov ebx, %1
    mov ecx, 0xABCD0123
    mov edx, 0x1234ABCD
    mov esi, 0x2345BCDE
    mov edi, 0x4567CDEF
    mov ebp, 0x5678DEFA
    call rn_check_ptree
    cmp eax, %2
    call pass_if.z
    cmp ebx, %3
    call pass_if.z
%if 1
    cmp ecx, 0xABCD0123
    call pass_if.z
    cmp edx, 0x1234ABCD
    call pass_if.z
    cmp esi, 0x2345BCDE
    call pass_if.z
    cmp edi, 0x4567CDEF
    call pass_if.z
    cmp ebp, 0x5678DEFA
    call pass_if.z
%endif
%endmacro

test_validity_check_1:
    call next_subtest
    t_check fixint_value(42),    err_invalid_ptree, fixint_value(42)
    t_check inert_tag,           err_invalid_ptree, inert_tag
    t_check boolean_value(0),    err_invalid_ptree, boolean_value(0)
    t_check symbol_value(5),     0, symbol_value(5)
    t_check keyword_value(6),    0, keyword_value(6)
    t_check string_value(7),     err_invalid_ptree, string_value(7)
    t_check bytevector_value(8), err_invalid_ptree, bytevector_value(8)
    t_check nonpair_object,      err_invalid_ptree, nonpair_object
    ret

test_validity_check_2:
    call next_subtest
    t_check rom_pair_value(list_1),   0, rom_pair_value(list_1)
    t_check rom_pair_value(list_2),   0, rom_pair_value(list_2)
    t_check rom_pair_value(list_3),   0, rom_pair_value(list_3)
    t_check rom_pair_value(list_4),   0, rom_pair_value(list_4)
    t_check rom_pair_value(list_5a),  err_invalid_ptree, fixint_value(3)
    t_check rom_pair_value(list_5b),  err_repeated_symbol, symbol_value(1)
    t_check rom_pair_value(cycle_1),  err_cyclic_ptree, rom_pair_value(cycle_1)
    t_check rom_pair_value(cycle_2a), err_cyclic_ptree, rom_pair_value(cycle_2a)
    ret

%macro t_match 3
    mov eax, 0x12345678
    mov ebx, %1
    mov ecx, 0xABCD0123
    mov edx, %2
    mov esi, 0x2345BCDE
    mov edi, 0x4567CDEF
    mov ebp, 0x5678DEFA
    call rn_match_ptree_procz
    call %3
%if 1
    cmp eax, 0x12345678
    call pass_if.z
    cmp ebx, %1
    call pass_if.z
    cmp ecx, 0xABCD0123
    call pass_if.z
    cmp edx, %2
    call pass_if.z
    cmp esi, 0x2345BCDE
    call pass_if.z
    cmp edi, 0x4567CDEF
    call pass_if.z
    cmp ebp, 0x5678DEFA
    call pass_if.z
%endif
%endmacro

test_match_1:
    call next_subtest
    t_match symbol_value(1), fixint_value(5), pass_if.z
    t_match ignore_tag, fixint_value(5), pass_if.z
    t_match nil_tag, nil_tag, pass_if.z
    t_match nil_tag, fixint_value(5), pass_if.nz
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
    dd ignore_tag
    dd nil_tag
list_2:
    dd symbol_value(1)
    dd rom_pair_value(list_1)
list_3:
    dd rom_pair_value(list_1)
    dd rom_pair_value(list_2)
list_4:
    dd symbol_value(2)
    dd rom_pair_value(list_3)
list_5a:
    dd fixint_value(3)
    dd rom_pair_value(list_4)
list_5b:
    dd symbol_value(1)
    dd rom_pair_value(list_4)

cycle_1:
    dd symbol_value(2)
    dd rom_pair_value(cycle_1)

cycle_2a:
    dd nil_tag
    dd rom_pair_value(cycle_2b)
cycle_2b:
    dd ignore_tag
    dd rom_pair_value(cycle_2a)

private_env_object:
    dd 0xDEADBEEF

lisp_rom_limit:
