%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0300
err_out_of_blob_memory          equ 0xDEAD0400
err_internal_error              equ 0xDEAD0500
err_invalid_blob_heap_operation equ 0xDEAD0600
private_lookup_table_length     equ 0

rn_out_of_memory:
rn_error:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/blob-data.asm"
%include "runtime/blob-garbage.asm"
%include "runtime/blob-allocator.asm"
%include "runtime/blob-bits.asm"
%include "runtime/critbit.asm"

%define blob_A     test_buffer + 4
%define blob_B     test_buffer + 8
%define blob_C     test_buffer + 12
%define blob_D     test_buffer + 16
%define tree       test_buffer + 20

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call init_blob_heap

    mov ecx, 1
    call rn_allocate_blob
    mov [blob_A], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'A'

    mov ecx, 1
    call rn_allocate_blob
    mov [blob_B], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'B'

    mov ecx, 1
    call rn_allocate_blob
    mov [blob_C], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'C'

    mov ecx, 1
    call rn_allocate_blob
    mov [blob_D], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'D'

    call test_insert_0
    call test_insert_1a
    call test_insert_1b
    call test_insert_n
    jmp test_finished

test_insert_0:
    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov [esi], dword nil_tag

    mov ebx, [blob_A]
    mov ecx, 0x01234567
    mov edx, 0x12344321
    call cb_insert
    call pass_if.nz
    cmp esi, tree
    call pass_if.z
    cmp edi, fixint_value(0)

    cmp ebx, [blob_A]
    call pass_if.z
    cmp ecx, 0x01234567
    call pass_if.z
    cmp edx, 0x12344321
    call pass_if.z

    mov [esi + edi - 1], ebx
    ret

test_insert_1a:
    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_A]
    mov ecx, 0x01234567
    mov edx, 0x12344321
    call cb_insert
    call pass_if.z

    cmp ebx, [blob_A]
    call pass_if.z
    cmp ecx, 0x01234567
    call pass_if.z
    cmp edx, 0x12344321
    call pass_if.z
    cmp esi, tree
    call pass_if.z
    cmp edi, fixint_value(0)
    call pass_if.z
    ret

test_insert_1b:
    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_B]
    mov ecx, 0x12488421
    mov edx, 0x12344321
    call cb_insert
    call pass_if.nz

    cmp ebx, [blob_B]
    call pass_if.z
    cmp ecx, 0x12488421
    call pass_if.z
    cmp edx, 0x12344321
    call pass_if.z
    mov eax, [tree]
    cmp eax, esi
    call pass_if.z
    cmp edi, fixint_value(3)
    call pass_if.z

    cmp [esi + critbit.header], dword critbit_header
    call pass_if.z
    cmp [esi + critbit.index], dword fixint_value(6)
    call pass_if.z

    mov eax, [blob_A]
    cmp [esi + critbit.child0], eax
    call pass_if.z

    mov [esi + edi - 1], ebx
    ret

test_insert_n:
    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_A]
    call cb_insert
    call pass_if.z
    cmp esi, tree
    call pass_if.z
    cmp edi, fixint_value(0)
    call pass_if.z
    mov ebx, [blob_B]
    call cb_insert
    call pass_if.z
    cmp esi, tree
    call pass_if.z
    cmp edi, fixint_value(0)
    call pass_if.z

    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_C]
    call cb_insert
    call pass_if.nz
    cmp ebx, [blob_C]
    call pass_if.z
    mov eax, [tree]
    mov eax, [eax + critbit.child1]
    lea eax, [eax + critbit.child1]
    lea edx, [esi + edi - 1]
    cmp eax, edx
    call pass_if.z
    mov [esi + edi - 1], ebx

    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_A]
    call cb_insert
    call pass_if.z
    mov ebx, [blob_B]
    call cb_insert
    call pass_if.z
    mov ebx, [blob_C]
    call cb_insert
    call pass_if.z

    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_D]
    call cb_insert
    call pass_if.nz
    cmp ebx, [blob_D]
    call pass_if.z
    mov eax, [tree]
    lea eax, [eax + critbit.child1]
    lea edx, [esi + edi - 1]
    cmp eax, edx
    call pass_if.z
    mov [esi + edi - 1], ebx

    call next_subtest
    mov esi, tree
    mov edi, fixint_value(0)
    mov ebx, [blob_A]
    call cb_insert
    call pass_if.z
    mov ebx, [blob_B]
    call cb_insert
    call pass_if.z
    mov ebx, [blob_C]
    call cb_insert
    call pass_if.z
    mov ebx, [blob_D]
    call cb_insert
    call pass_if.z

    ret

section .lisp_rom
    align 8
lisp_rom_base:
lisp_rom_limit:
