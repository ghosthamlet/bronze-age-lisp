%include "macros.inc"
%include "testenv.asm"

;; mock

private_lookup_table_length equ 0
err_out_of_lisp_memory      equ 0xDEAD0010
err_internal_error          equ 0xDEAD0020

rn_get_blob_data:
    call fail
    ret
rn_out_of_memory:
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
%include "runtime/deep-copies.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_copy_nonpair
    call test_copy_immutable
    call test_copy_flat
    call test_copy_unshared
    call test_copy_shared
    call test_copy_cyclic
    jmp test_finished

test_copy_nonpair:
    call next_subtest
    mov ebx, fixint_value(42)
    mov ecx, 0x00000100
    mov edx, 0x00000F00
    mov esi, 0x00000200
    mov edi, 0x00000300
    mov ebp, 0x00000400
    call rn_copy_es_immutable
    cmp eax, fixint_value(42)
    call pass_if.z
    cmp ebx, fixint_value(42)
    call pass_if.z
    cmp ecx, 0x00000100
    call pass_if.z
    cmp edx, 0x00000F00
    call pass_if.z
    cmp esi, 0x00000200
    call pass_if.z
    cmp edi, 0x00000300
    call pass_if.z
    cmp ebp, 0x00000400
    ret

test_copy_immutable:
    call next_subtest
    mov ebx, rom_pair_value(list_2)
    mov ecx, 0x00000100
    mov edx, 0x00000F00
    mov esi, 0x00000200
    mov edi, 0x00000300
    mov ebp, 0x00000400
    call rn_copy_es_immutable
    cmp eax, rom_pair_value(list_2)
    call pass_if.z
    cmp ebx, rom_pair_value(list_2)
    call pass_if.z
    cmp ecx, 0x00000100
    call pass_if.z
    cmp edx, 0x00000F00
    call pass_if.z
    cmp esi, 0x00000200
    call pass_if.z
    cmp edi, 0x00000300
    call pass_if.z
    cmp ebp, 0x00000400
    ret

test_copy_flat:
    call next_subtest
    push rom_pair_value(list_2)
    push boolean_value(1)
    call rn_cons
    push eax
    mov ebx, eax
    mov ecx, 0x00000100
    mov edx, 0x00000F00
    mov esi, 0x00000200
    mov edi, 0x00000300
    mov ebp, 0x00000400
    call rn_copy_es_immutable
    cmp ecx, 0x00000100
    call pass_if.z
    cmp edx, 0x00000F00
    call pass_if.z
    cmp esi, 0x00000200
    call pass_if.z
    cmp edi, 0x00000300
    call pass_if.z
    cmp ebp, 0x00000400
    pop ecx
    cmp ebx, ecx
    call pass_if.z

    mov ebx, eax
    xor  ebx, 0x00000003
    test ebx, 0x80000003
    call pass_if.z
    cmp car(eax), dword rom_pair_value(list_2)
    call pass_if.z
    cmp cdr(eax), dword boolean_value(1)
    call pass_if.z
    ret

test_copy_unshared:
    call next_subtest
    push dword fixint_value(5)
    push dword nil_tag
    call rn_cons
    push eax

    push dword fixint_value(7)
    push eax
    call rn_cons
    push eax

    push dword fixint_value(9)
    push eax
    call rn_cons
    push eax

    ;; eax = (9 7 5)

    mov ebx, eax
    mov ecx, 0x00000100
    mov edx, 0x00000F00
    mov esi, 0x00000200
    mov edi, 0x00000300
    mov ebp, 0x00000400
    call rn_copy_es_immutable
    cmp ecx, 0x00000100
    call pass_if.z
    cmp edx, 0x00000F00
    call pass_if.z
    cmp esi, 0x00000200
    call pass_if.z
    cmp edi, 0x00000300
    call pass_if.z
    cmp ebp, 0x00000400

    ;; check original
    mov ecx, [esp]
    cmp ebx, ecx
    call pass_if.z
    cmp car(ebx), dword fixint_value(9)
    call pass_if.z
    mov edx, [esp + 4]
    cmp cdr(ebx), edx
    call pass_if.z

    mov ebx, cdr(ebx)
    cmp car(ebx), dword fixint_value(7)
    call pass_if.z
    mov edx, [esp + 8]
    cmp cdr(ebx), edx
    call pass_if.z

    mov ebx, cdr(ebx)
    cmp car(ebx), dword fixint_value(5)
    call pass_if.z
    cmp cdr(ebx), dword nil_tag
    call pass_if.z

    ;; check clone
    mov ebx, eax
    xor  ebx, 0x00000003
    test ebx, 0x80000003
    call pass_if.z

    cmp [esp], eax
    call pass_if.nz
    cmp car(eax), dword fixint_value(9)
    call pass_if.z

    mov ecx, cdr(eax)
    cmp [esp + 4], ecx
    call pass_if.nz
    cmp car(ecx), dword fixint_value(7)
    call pass_if.z

    mov ecx, cdr(ecx)
    cmp [esp + 8], ecx
    call pass_if.nz
    cmp car(ecx), dword fixint_value(5)
    call pass_if.z
    cmp cdr(ecx), dword nil_tag
    call pass_if.z

    add esp, 12
    ret

test_copy_shared:
    call next_subtest
    push dword fixint_value(1)
    push dword fixint_value(2)
    call rn_cons
    push eax

    push eax
    push eax
    call rn_cons
    push eax

    ;; eax = (#1=(1 . 2) #1#)

    mov ebx, eax
    mov ecx, 0x00000100
    mov edx, 0x00000F00
    mov esi, 0x00000200
    mov edi, 0x00000300
    mov ebp, 0x00000400
    call rn_copy_es_immutable
    cmp ecx, 0x00000100
    call pass_if.z
    cmp edx, 0x00000F00
    call pass_if.z
    cmp esi, 0x00000200
    call pass_if.z
    cmp edi, 0x00000300
    call pass_if.z
    cmp ebp, 0x00000400

    ;; check original
    mov ecx, [esp]
    cmp ebx, ecx
    call pass_if.z
    mov ecx, [esp + 4]
    cmp car(ebx), ecx
    call pass_if.z
    cmp cdr(ebx), ecx
    call pass_if.z
    cmp car(ecx), dword fixint_value(1)
    call pass_if.z
    cmp cdr(ecx), dword fixint_value(2)
    call pass_if.z

    ;; check clone
    mov ebx, eax
    xor  ebx, 0x00000003
    test ebx, 0x80000003
    call pass_if.z

    cmp [esp], eax
    call pass_if.nz
    mov ebx, car(eax)
    cmp cdr(eax), ebx
    call pass_if.z
    cmp [esp + 4], ebx
    call pass_if.nz
    cmp car(ebx), dword fixint_value(1)
    call pass_if.z
    cmp cdr(ebx), dword fixint_value(2)
    call pass_if.z

    add esp, 8
    ret

test_copy_cyclic:
    call next_subtest
    push dword fixint_value(3)
    push inert_tag
    call rn_cons
    push eax
    push dword fixint_value(2)
    push eax
    call rn_cons
    push dword fixint_value(1)
    push eax
    call rn_cons
    pop ecx
    mov cdr(ecx), eax

    ;; eax = #0=(1 2 3 . #0#)

    mov ebx, eax
    call rn_copy_es_immutable

    ;; check cycle
    mov ecx, eax
    mov ecx, cdr(eax)
    cmp ecx, eax
    call pass_if.nz
    mov ecx, cdr(ecx)
    cmp ecx, eax
    call pass_if.nz
    mov ecx, cdr(ecx)
    cmp ecx, eax
    call pass_if.z

    ;; check contents
    cmp car(eax), dword fixint_value(1)
    call pass_if.z
    mov ecx, cdr(eax)
    cmp car(ecx), dword fixint_value(2)
    call pass_if.z
    mov ecx, cdr(ecx)
    cmp car(ecx), dword fixint_value(3)
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
