%include "macros.inc"
%include "testenv.asm"
%include "applicative-support.inc"

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
err_invalid_argument_structure  equ 0xDEAD0E00
err_not_a_combiner              equ 0xDEAD0F00
err_unbound_symbol              equ 0xDEAD1000

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
%include "runtime/list-metrics.asm"
%include "runtime/list-construction.asm"
%include "runtime/evaluator.asm"
%include "runtime/applicatives.asm"

    align 4
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_wrap
    call test_unwrap
    jmp test_finished

test_wrap:
    call next_subtest
    mov ebx, operative_1
    call rn_wrap
    test al, 3
    call pass_if.z
    mov ecx, [eax]
    cmp cl, applicative_header(0)
    call pass_if.z
    mov edx, [eax + applicative.underlying]
    cmp edx, operative_1
    call pass_if.z
    ret

test_unwrap:
    call next_subtest
    mov ebx, operative_1
    call rn_fully_unwrap
    cmp eax, operative_1
    call pass_if.z
    cmp ecx, 0
    call pass_if.z

    mov ebx, operative_1
    call rn_wrap
    mov ebx, eax
    call rn_fully_unwrap
    cmp eax, operative_1
    call pass_if.z
    cmp ecx, 1
    call pass_if.z

    mov ebx, operative_1
    call rn_wrap
    mov ebx, eax
    call rn_wrap
    mov ebx, eax
    call rn_fully_unwrap
    cmp eax, operative_1
    call pass_if.z
    cmp ecx, 2
    call pass_if.z

    ret

section .lisp_rom
    align 8
lisp_rom_base:

    align 8
operative_1:
    dd operative_header(2)
    dd 0xDEADBEEF

lisp_rom_limit:
