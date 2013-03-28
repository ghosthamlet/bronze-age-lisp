%include "macros.inc"
%include "testenv.asm"

;; mock

private_lookup_table_length equ 0
err_out_of_lisp_memory      equ 0xDEAD0010
err_internal_error          equ 0xDEAD0020

rn_get_blob_data:
    call fail
    ret
rn_error:
    call fail
    jmp rn_fatal

ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/list-metrics.asm"
%include "runtime/list-construction.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_rev_0
    call test_rev_1
    call test_rev_2
    call test_build_1
    call test_build_2
    jmp test_finished

test_rev_0:
    call next_subtest
    mov eax, nil_tag
    mov ebx, fixint_value(42)
    mov ecx, 0x12340001
    mov edx, fixint_value(0)
    mov esi, 0x23450001
    mov ebp, 0x34560001
    call rn_list_rev
    cmp eax, nil_tag
    call pass_if.z
    cmp ebx, fixint_value(42)
    call pass_if.z
    cmp ecx, 0x12340001
    call pass_if.z
    cmp edx, fixint_value(0)
    call pass_if.z
    cmp esi, 0x23450001
    call pass_if.z
    cmp ebp, 0x34560001
    call pass_if.z
    ret

test_rev_1:
    call next_subtest
    mov eax, rom_pair_value(list_1)
    mov ebx, fixint_value(42)
    mov ecx, 0x12340001
    mov edx, fixint_value(1)
    mov esi, 0x23450001
    mov ebp, 0x34560001
    call rn_list_rev
    cmp eax, nil_tag
    call pass_if.z
    call rn_pairP_procz
    call pass_if.z
    cmp car(ebx), dword fixint_value(100)
    call pass_if.z
    cmp cdr(ebx), dword fixint_value(42)
    call pass_if.z
    cmp ecx, 0x12340001
    call pass_if.z
    cmp edx, fixint_value(1)
    call pass_if.z
    cmp esi, 0x23450001
    call pass_if.z
    cmp ebp, 0x34560001
    call pass_if.z
    ret

test_rev_2:
    call next_subtest
    mov eax, rom_pair_value(list_2)
    mov ebx, fixint_value(43)
    mov ecx, 0x12340001
    mov edx, fixint_value(2)
    mov esi, 0x23450001
    mov ebp, 0x34560001
    call rn_list_rev
    cmp eax, nil_tag
    call pass_if.z
    call rn_pairP_procz
    call pass_if.z
    cmp car(ebx), dword fixint_value(100)
    call pass_if.z
    mov ebx, cdr(ebx)
    call rn_pairP_procz
    call pass_if.z
    cmp car(ebx), dword fixint_value(200)
    call pass_if.z
    cmp cdr(ebx), dword fixint_value(43)
    call pass_if.z
    cmp ecx, 0x12340001
    call pass_if.z
    cmp edx, fixint_value(2)
    call pass_if.z
    cmp esi, 0x23450001
    call pass_if.z
    cmp ebp, 0x34560001
    call pass_if.z
    ret

test_build_1:
    call next_subtest
    mov eax, rom_pair_value(list_2)
    mov ebx, 0x12340001
    mov ecx, fixint_value(1)
    mov edx, fixint_value(1)
    mov esi, 0x23450001
    mov ebp, 0x34560001
    call rn_list_rev_build
    cmp eax, rom_pair_value(list_1)
    call pass_if.z
    call rn_pairP_procz
    call pass_if.z
    cmp car(ebx), dword fixint_value(200)
    call pass_if.z
    cmp ebx, cdr(ebx)
    call pass_if.z
    cmp ecx, fixint_value(1)
    call pass_if.z
    cmp edx, fixint_value(1)
    call pass_if.z
    cmp esi, 0x23450001
    call pass_if.z
    cmp ebp, 0x34560001
    call pass_if.z
    ret

test_build_2:
    call next_subtest
    mov eax, rom_pair_value(list_2)
    mov ebx, 0x12340001
    mov ecx, fixint_value(2)
    mov edx, fixint_value(2)
    mov esi, 0x23450001
    mov ebp, 0x34560001
    call rn_list_rev_build
    cmp eax, nil_tag
    call pass_if.z
    call rn_pairP_procz
    call pass_if.z
    cmp car(ebx), dword fixint_value(100)
    call pass_if.z
    mov eax, cdr(ebx)
    cmp car(eax), dword fixint_value(200)
    call pass_if.z
    cmp ebx, cdr(eax)
    call pass_if.z
    cmp ecx, fixint_value(2)
    call pass_if.z
    cmp edx, fixint_value(2)
    call pass_if.z
    cmp esi, 0x23450001
    call pass_if.z
    cmp ebp, 0x34560001
    call pass_if.z
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
