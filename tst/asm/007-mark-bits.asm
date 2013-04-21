%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0003
err_out_of_blob_memory          equ 0xDEAD0004
err_internal_error              equ 0xDEAD0005
err_invalid_blob_heap_operation equ 0xDEAD0006
private_lookup_table_length     equ 0

rn_get_blob_data:
    call fail
    ret
rn_out_of_memory:
rn_error:
    jmp rn_fatal

ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/mark-bits.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_base_address
    call test_other
    call test_rom
    call test_ram
    jmp test_finished

test_base_address:
    call next_subtest

    call rn_mark_base_32
    mov eax, esi
    xor eax, [lisp_heap_pointer]
    test eax, configured_lisp_heap_size
    call pass_if.nz
    mov ebx, esi

    call rn_mark_base_8
    mov eax, esi
    xor eax, [lisp_heap_pointer]
    test eax, configured_lisp_heap_size
    call pass_if.nz
    mov ecx, esi

    call rn_mark_base_1
    mov eax, esi
    xor eax, [lisp_heap_pointer]
    test eax, configured_lisp_heap_size
    call pass_if.nz
    mov edx, esi

    cmp ebx, ecx
    call pass_if.b
    cmp ecx, edx
    call pass_if.b
    ret

test_other:
    call next_subtest
    mov ebx, fixint_value(42)
    call rn_mark_index
    cmp eax, all_mark_slots - 1
    call pass_if.z

    mov ebx, nil_tag
    call rn_mark_index
    cmp eax, all_mark_slots - 1
    call pass_if.z

    mov ebx, symbol_value(1)
    call rn_mark_index
    cmp eax, all_mark_slots - 1
    call pass_if.z
    ret

test_rom:
    call next_subtest
    mov ebx, rom_pair_value(list_1)
    call rn_mark_index
    mov ecx, eax
    mov ebx, rom_pair_value(list_2)
    call rn_mark_index
    cmp eax, ecx
    call pass_if.nz
    ret

test_ram:
    call next_subtest
    push dword fixint_value(9)
    push dword fixint_value(10)
    call rn_cons
    mov ebx, eax
    call rn_mark_index
    mov ecx, eax

    push dword fixint_value(9)
    push dword fixint_value(10)
    call rn_cons
    mov ebx, eax
    call rn_mark_index
    mov edx, eax
    cmp ecx, edx
    call pass_if.nz

    mov ecx, 4
    call rn_allocate
    mov ebx, eax
    call rn_mark_index
    cmp eax, ecx
    call pass_if.nz
    cmp eax, edx
    call pass_if.nz
    ret

section .lisp_rom
    align 8
lisp_rom_base:
list_2:
    dd fixint_value(200)
    dd rom_pair_value(list_1)
list_1:
    dd fixint_value(100)
    dd nil_tag
lisp_rom_limit: