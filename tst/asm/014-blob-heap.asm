%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0300
err_out_of_blob_memory          equ 0xDEAD0400
err_internal_error              equ 0xDEAD0500
err_invalid_blob_heap_operation equ 0xDEAD0600
private_lookup_table_length     equ 0

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

%define saved_blob_space test_buffer
%define saved_value      test_buffer + 4
%define saved_pointer    test_buffer + 8

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_init

    call free_blob_space
    mov [saved_blob_space], eax

    call test_dry_run
    call test_alloc
    call test_repeat
    call test_garbage
    call test_move

    jmp test_finished

free_blob_space:
    push ebx
    push ecx
    mov ebx, [free_blob]
    mov ecx, blob_next(ebx)
    mov eax, blob_address(ecx)
    sub eax, blob_address(ebx)
    pop ecx
    pop ebx
    ret

free_list_length:
    push ecx
    mov eax, [free_blob]
    xor ecx, ecx
    test eax, eax
    jz .done
  .next:
    inc ecx
    mov eax, blob_next(eax)
    test eax, eax
    jnz .next
    mov eax, ecx
  .done:
    pop ecx
    ret

test_init:
    call next_subtest
    call init_blob_heap
    mov eax, [free_blob]
    cmp eax, 1 + (blob_descriptors.ram - blob_descriptors)
    call pass_if.z
    mov ebx, [first_blob]
    cmp eax, ebx
    call pass_if.z
    call free_list_length
    cmp eax, 42
    call pass_if.z
    ret

test_dry_run:
    call next_subtest
    call init_blob_heap
    %rep 3
    call bl_collect
    call free_list_length
    cmp eax, 42
    call pass_if.z
    call free_blob_space
    cmp eax, [saved_blob_space]
    call pass_if.z
    %endrep
    ret

test_alloc:
    call next_subtest
    mov eax, 0xAAAA0001
    mov ebx, 0xBBBB0001
    mov ecx, 13
    mov edx, 0xCCCC0001
    mov esi, 0xDDDD0001
    mov edi, 0xEEEE0001
    mov ebp, 0xFFFF0001
    call rn_allocate_blob
    cmp ebx, 0xAAAA0001
    call pass_if.nz
    cmp al, bytevector_tag
    call pass_if.z
    cmp ebx, 0xBBBB0001
    call pass_if.z
    cmp ecx, 13
    call pass_if.z
    cmp edx, 0xCCCC0001
    call pass_if.z
    cmp edi, 0xEEEE0001
    call pass_if.z
    cmp ebp, 0xFFFF0001
    call pass_if.z
    mov ebx, eax
    mov ecx, 0x12345678
    call rn_get_blob_data
    cmp ecx, 13
    call pass_if.z
    call free_blob_space
    add eax, 13
    cmp eax, [saved_blob_space]
    call pass_if.z
    ret

test_repeat:
    ; assumes: blob-heap-size=4096
    call next_subtest
    call init_lisp_heap
    call init_blob_heap
    %assign s 0
  %rep 3
    call next_subtest
    %if (s == 0)
    %assign n 6
    %else
    %assign n 5
    %endif
   %rep n
    call next_subtest
    call free_blob_space
    mov ebx, eax
    add eax, s
    cmp eax, [saved_blob_space]
    call pass_if.z
    mov eax, 0xAAAA0001
    mov ebx, 0xBBBB0001
    mov ecx, 791
    mov edx, 0xCCCC0001
    mov esi, 0xDDDD0001
    mov ebp, 0xFFFF0001
    call rn_allocate_blob
    cmp ebx, 0xAAAA0001
    call pass_if.nz
    cmp al, bytevector_tag
    call pass_if.z
    cmp ebx, 0xBBBB0001
    call pass_if.z
    cmp ecx, 791
    call pass_if.z
    cmp edx, 0xCCCC0001
    call pass_if.z
    cmp ebp, 0xFFFF0001
    call pass_if.z
    mov ebx, eax
    mov ecx, 0x12345678
    call rn_get_blob_data
    cmp ecx, 791
    call pass_if.z
    %assign s (s + 791)
   %endrep
    %assign s 791
  %endrep
    ret

test_garbage:
    call next_subtest
    call init_lisp_heap
    call init_blob_heap

    mov ecx, 17
    call rn_allocate_blob
    push eax
    mov ecx, 19
    call rn_allocate_blob
    mov ecx, 21
    call rn_allocate_blob
    push eax
    mov ecx, 23
    call rn_allocate_blob
    mov ebx, eax
    mov ecx, 25
    call rn_allocate_blob

    call free_blob_space
    add eax, 17 + 19 + 21 + 23 + 25
    cmp eax, [saved_blob_space]
    call pass_if.z

    xor eax, eax
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor ebp, ebp
    call bl_collect

    call free_blob_space
    add eax, 17 + 21 + 23
    cmp eax, [saved_blob_space]
    call pass_if.z

    pop eax
    pop eax
    ret

test_move:
    call next_subtest
    call init_lisp_heap
    call init_blob_heap

    mov ecx, 1
    call rn_allocate_blob
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'A'

    mov ecx, 1
    call rn_allocate_blob
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'B'

    mov ecx, 1
    call rn_allocate_blob
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'C'
    mov edx, eax
    mov [saved_value], eax
    mov [saved_pointer], ebx

    mov ecx, 1
    call rn_allocate_blob
    push eax
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'D'

    mov ecx, 1
    call rn_allocate_blob
    mov ebx, eax
    call rn_get_blob_data
    mov [ebx], byte 'E'

    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor esi, esi
    xor ebp, ebp
    call bl_collect

    cmp edx, [saved_value]
    call pass_if.z

    mov ebx, edx
    call rn_get_blob_data
    cmp ebx, [saved_pointer]
    call pass_if.nz
    cmp [ebx], byte 'C'
    call pass_if.z
    cmp ecx, 1
    call pass_if.z

    pop ebx
    call rn_get_blob_data
    cmp ebx, [saved_pointer]
    call pass_if.nz
    cmp [ebx], byte 'D'
    call pass_if.z
    cmp ecx, 1
    call pass_if.z

    ret

section .lisp_rom
    align 8
lisp_rom_base:
lisp_rom_limit: