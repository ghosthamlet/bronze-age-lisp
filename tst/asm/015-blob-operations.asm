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

%define empty_blob test_buffer
%define blob_A     test_buffer + 4
%define blob_B     test_buffer + 8
%define blob_AB    test_buffer + 12
%define blob_7F    test_buffer + 16
%define blob_A7F   test_buffer + 20

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call init_blob_heap

    mov ecx, 0
    call rn_allocate_blob
    mov [empty_blob], eax

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

    mov ecx, 2
    call rn_allocate_blob
    mov [blob_AB], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'A'
    mov [ebx+1], byte 'B'

    mov ecx, 1
    call rn_allocate_blob
    mov [blob_7F], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 0x7F

    mov ecx, 2
    call rn_allocate_blob
    mov [blob_A7F], eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'A'
    mov [ebx+1], byte 0x7F

    call test_bit
    call test_compare_bit
;    call test_compare_sgn
    jmp test_finished

%macro check_bit 3
    mov eax, %1
    mov ebx, %2
    call rn_blob_bit
    cmp eax, %3
    call pass_if.z
%endmacro

%macro check_compare_bit 5
    mov eax, %1
    mov ebx, %2
    call rn_compare_blob_bits
    setz al
    setc bl
    cmp al, %3
    call pass_if.z
    cmp bl, %4
    call pass_if.z
    cmp ecx, %5
    call pass_if.z
 ;   mov eax, ecx
 ;   call print_decimal
%endmacro


test_bit:
    call next_subtest
    check_bit 0, [empty_blob], 0
    check_bit 1, [empty_blob], 1
    check_bit 2, [empty_blob], 1
    check_bit 5, [empty_blob], 1
    check_bit 6, [empty_blob], 1
    check_bit 7, [empty_blob], 1
    check_bit 8, [empty_blob], 1
    check_bit 9, [empty_blob], 1
    check_bit 99, [empty_blob], 1

    call next_subtest
    check_bit 0, [blob_A], 0
    check_bit 1, [blob_A], 1
    check_bit 2, [blob_A], 0
    check_bit 3, [blob_A], 0
    check_bit 4, [blob_A], 0
    check_bit 5, [blob_A], 0
    check_bit 6, [blob_A], 0
    check_bit 7, [blob_A], 1
    check_bit 8, [blob_A], 0
    check_bit 9, [blob_A], 1
    check_bit 10, [blob_A], 1

    call next_subtest
    check_bit  0, [blob_AB], 0
    check_bit  1, [blob_AB], 1
    check_bit  2, [blob_AB], 0
    check_bit  3, [blob_AB], 0
    check_bit  4, [blob_AB], 0
    check_bit  5, [blob_AB], 0
    check_bit  6, [blob_AB], 0
    check_bit  7, [blob_AB], 1
    check_bit  8, [blob_AB], 0
    check_bit  9, [blob_AB], 1
    check_bit 10, [blob_AB], 0
    check_bit 11, [blob_AB], 0
    check_bit 12, [blob_AB], 0
    check_bit 13, [blob_AB], 0
    check_bit 14, [blob_AB], 1
    check_bit 15, [blob_AB], 0
    check_bit 16, [blob_AB], 0
    check_bit 17, [blob_AB], 1
    check_bit 18, [blob_AB], 1
    ret

test_compare_bit:
    call next_subtest
    call next_subtest

    check_compare_bit [empty_blob], [empty_blob], 1, 1, 0xFFFFFFFF
    check_compare_bit [empty_blob], [blob_A], 0, 1, 2
    check_compare_bit [blob_A], [empty_blob], 0, 0, 2
    check_compare_bit [blob_A], [blob_A], 1, 1, 0xFFFFFFFF

    call next_subtest
    check_compare_bit [blob_A], [blob_B], 0, 0, 6
    check_compare_bit [blob_B], [blob_A], 0, 1, 6

    call next_subtest
    check_compare_bit [blob_A], [blob_AB], 0, 1, 10
    check_compare_bit [blob_AB], [blob_A], 0, 0, 10

    call next_subtest
    check_compare_bit [empty_blob], [blob_7F], 0, 1, 8
    check_compare_bit [blob_7F], [empty_blob], 0, 0, 8
    check_compare_bit [blob_A],  [blob_A7F], 0, 1, 16
    check_compare_bit [blob_A7F], [blob_A], 0, 0, 16

    ret

section .lisp_rom
    align 8
lisp_rom_base:
lisp_rom_limit:
