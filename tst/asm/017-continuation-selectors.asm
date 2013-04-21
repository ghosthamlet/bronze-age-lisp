%include "macros.inc"
%include "testenv.asm"
%include "runtime/continuation-ancestry.asm"
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
err_unbound_symbol              equ 0xDEAD0E00
err_not_a_combiner              equ 0xDEAD0F00
err_invalid_argument_structure  equ 0xDEAD1000

private_lookup_table_length     equ 0
ground_lookup_table_length      equ 0

rn_get_blob_data:
    call fail
    ret
rn_out_of_memory:
rn_error:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/evaluator.asm"
%include "runtime/applicatives.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/list-construction.asm"
%include "runtime/guarded-continuations.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_select
    call test_entry_chain
    call test_exit_chain
    call test_full_chain
    call test_empty_chain
    jmp test_finished


test_select:
    call next_subtest

    mov ebx, guard_inner
    mov ecx, error_continuation
    call rn_select_one
    call pass_if.z
    cmp eax, 0xAAAA0200
    call pass_if.z
    cmp edi, 0xEEEE0200
    call pass_if.z

    mov ebx, guard_inner
    mov ecx, root_continuation
    call rn_select_one
    call pass_if.z
    cmp eax, 0xAAAA0300
    call pass_if.z
    cmp edi, 0xEEEE0200
    call pass_if.z

    mov ebx, guard_inner
    mov ecx, guard_inner
    call rn_select_one
    call pass_if.z
    cmp eax, 0xAAAA0300
    call pass_if.z
    cmp edi, 0xEEEE0200
    call pass_if.z

    mov ebx, guard_outer
    mov ecx, guard_inner
    call rn_select_one
    call pass_if.nz
    cmp eax, nil_tag
    call pass_if.z

    mov ebx, guard_outer
    mov ecx, error_continuation
    call rn_select_one
    call pass_if.z
    cmp eax, 0xAAAA0100
    call pass_if.z
    cmp edi, 0xEEEE0100
    call pass_if.z

    ret

test_entry_chain:
    call next_subtest

    mov ebx, guard_inner
    mov ecx, error_continuation
    mov edx, root_continuation
    mov esi, dummy_continuation
    call rn_select_entry_guards

    mov eax, esi
    test al, 3
    call pass_if.z
    cmp [esi +  0], dword cont_header(6)
    call pass_if.z
    cmp [esi +  4], dword cont_intercept
    call pass_if.z
    cmp [esi +  8], dword guard_outer
    call pass_if.z
    cmp [esi + 12], dword 0xEEEE0100
    call pass_if.z
    cmp [esi + 16], dword dummy_continuation
    call pass_if.z
    cmp [esi + 20], dword 0xAAAA0100
    call pass_if.z
    ret

test_exit_chain:
    call next_subtest

    mov ebx, guard_inner
    mov ecx, error_continuation
    mov edx, root_continuation
    lea esi, [test_buffer - cont.var1]
    mov [test_buffer], dword dummy_continuation
    call rn_select_exit_guards

    lea eax, [test_buffer - cont.var1]
    cmp esi, eax
    call pass_if.nz

    mov eax, [test_buffer]
    cmp esi, eax
    call pass_if.z

    test esi, 3
    call pass_if.z
    cmp [esi +  0], dword cont_header(6)
    call pass_if.z
    cmp [esi +  4], dword cont_intercept
    call pass_if.z
    cmp [esi +  8], dword guard_outer
    call pass_if.z
    cmp [esi + 12], dword 0xEEEE0200
    call pass_if.z
    cmp [esi + 16], dword inert_tag
    call pass_if.z
    cmp [esi + 20], dword 0xAAAA0200
    call pass_if.z
    ret

test_full_chain:
    call next_subtest

    mov eax, guard_inner
    mov ebx, guard_inner_2
    call rn_select_all_guards
    cmp eax, ebx
    call pass_if.z

    ;; check chain pointers
    mov ecx, [ebx + cont.var1]
    mov edx, [ecx + cont.var1]
    cmp edx, guard_inner_2
    call pass_if.z
    cmp ebx, ecx
    call pass_if.nz

    ;; check parent pointers
    cmp [ebx + cont.parent], dword guard_outer
    call pass_if.z
    cmp [ecx + cont.parent], dword guard_outer_2
    call pass_if.z

    ;; check environments and operatives
    cmp [ebx + cont.var0], dword 0xEEEE0200
    call pass_if.z
    cmp [ebx + cont.var2], dword 0xAAAA0200
    call pass_if.z
    cmp [ecx + cont.var0], dword 0xEEEE0400
    call pass_if.z
    cmp [ecx + cont.var2], dword 0xAAAA0400
    call pass_if.z

    ;; check headers and program pointers
    cmp [ebx + cont.header], dword cont_header(6)
    call pass_if.z
    cmp [ebx + cont.program], dword cont_intercept
    call pass_if.z
    cmp [ecx + cont.header], dword cont_header(6)
    call pass_if.z
    cmp [ebx + cont.program], dword cont_intercept
    call pass_if.z

    ret

test_empty_chain:
    call next_subtest
    mov eax, error_continuation
    mov ebx, root_continuation
    call rn_select_all_guards
    cmp ebx, eax
    call pass_if.z
    cmp ebx, root_continuation
    call pass_if.z
    ret

section .lisp_rom
    align 8
lisp_rom_base:

root_continuation:
    dd cont_header(4)
    dd 0xDEADBEEF
    dd inert_tag
    dd 0

error_continuation:
    dd cont_header(4)
    dd 0xDEADBEEF
    dd root_continuation
    dd 0

guard_outer:
    dd cont_header(6)
    dd cont_outer
    dd root_continuation
    dd 0xEEEE0100
    dd error_continuation
    dd 0xAAAA0100

guard_inner:
    dd cont_header(8)
    dd cont_inner
    dd guard_outer
    dd 0xEEEE0200
    dd error_continuation
    dd 0xAAAA0200
    dd root_continuation
    dd 0xAAAA0300

guard_outer_2:
    dd cont_header(6)
    dd cont_outer
    dd error_continuation
    dd 0xEEEE0400
    dd guard_outer
    dd 0xAAAA0400

guard_inner_2:
    dd cont_header(8)
    dd cont_inner
    dd guard_outer_2
    dd 0xEEEE0500
    dd guard_outer
    dd 0xAAAA0500

dummy_continuation:
    dd cont_header(4)
    dd 0xDDDDDDD0
    dd 0xDDDDDDD0
    dd 0xDDDDDDD0

lisp_rom_limit:
