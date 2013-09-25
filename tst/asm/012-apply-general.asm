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
rn_out_of_memory:
rn_error:
rn_sequence:
tail_env_lookup:
list_env_lookup:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%define private_binding(x) 0xDEAD1100
%define empty_env_object   0xDEAD1200

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
    call test_acyclic_0
    call test_acyclic_1
    call test_acyclic_2
    call test_acyclic_3
    jmp test_finished

%macro def_data 0
    align 8
  .app_obj:
    dd applicative_header(4)
    dd 0xDEADBEEF
    dd .operative_obj
    dd 0
  .operative_obj:
    dd operative_header(4)
    dd .operate
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd 0xDEADBEEF
    dd 0xDEADBEEF
%endmacro

test_acyclic_0:
    call next_subtest
    mov eax, .app_obj
    mov ebx, nil_tag
    mov edi, dummy_env
    mov ebp, .cont_obj
    jmp rn_generic_applicative
  .operate:
    cmp eax, .operative_obj
    call pass_if.z
    cmp ebx, nil_tag
    call pass_if.z
    mov eax, fixint_value(42)
    jmp [ebp + cont.program]
  .cont:
    cmp eax, fixint_value(42)
    call pass_if.z
    ret
    def_data

test_acyclic_1:
    call next_subtest
    mov eax, .app_obj
    mov ebx, rom_pair_value(list_1)
    mov edi, dummy_env
    mov ebp, .cont_obj
    jmp rn_generic_applicative
  .operate:
    cmp eax, .operative_obj
    call pass_if.z
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    mov ecx, car(ebx)
    mov edx, cdr(ebx)
    cmp ecx, fixint_value(15)
    call pass_if.z
    cmp edx, nil_tag
    call pass_if.z
    mov eax, fixint_value(43)
    jmp [ebp + cont.program]
  .cont:
    cmp eax, fixint_value(43)
    call pass_if.z
    ret
    def_data

test_acyclic_2:
    call next_subtest
    mov eax, .app_obj
    mov ebx, rom_pair_value(list_2)
    mov edi, dummy_env
    mov ebp, .cont_obj
    jmp rn_generic_applicative
  .operate:
    cmp eax, .operative_obj
    call pass_if.z
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    cmp car(ebx), dword fixint_value(25)
    call pass_if.z

    mov ebx, cdr(ebx)
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    cmp car(ebx), dword fixint_value(35)
    call pass_if.z

    cmp cdr(ebx), dword nil_tag
    call pass_if.z
    mov eax, fixint_value(44)
    jmp [ebp + cont.program]
  .cont:
    cmp eax, fixint_value(44)
    call pass_if.z
    ret
    def_data

test_acyclic_3:
    call next_subtest
    mov eax, .app_obj
    mov ebx, rom_pair_value(list_3)
    mov edi, dummy_env
    mov ebp, .cont_obj
    jmp rn_generic_applicative
  .operate:
    cmp eax, .operative_obj
    call pass_if.z
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    cmp car(ebx), dword fixint_value(15)
    call pass_if.z

    mov ebx, cdr(ebx)
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    cmp car(ebx), dword fixint_value(25)
    call pass_if.z

    mov ebx, cdr(ebx)
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    cmp car(ebx), dword fixint_value(35)
    call pass_if.z

    cmp cdr(ebx), dword nil_tag
    call pass_if.z
    mov eax, fixint_value(44)
    jmp [ebp + cont.program]
  .cont:
    cmp eax, fixint_value(44)
    call pass_if.z
    ret
    def_data

test_primitive:
    mov ebx, car(ebx)
    mov eax, ebx
    add eax, 5 << 2
    jmp [ebp + cont.program]

section .lisp_rom
    align 8
lisp_rom_base:

dummy_env:
    dd environment_header(4)
    dd 0xDEADBEEF
    dd 0xDEADBEEF
    dd 0xDEADBEEF

combination_1:
    dd primitive_value(test_primitive)
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(10)
    dd nil_tag

combination_2:
    dd primitive_value(test_primitive)
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(20)
    dd nil_tag

combination_3:
    dd primitive_value(test_primitive)
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(30)
    dd nil_tag

list_1:
    dd rom_pair_value(combination_1)
    dd nil_tag

list_2:
    dd rom_pair_value(combination_2)
    dd rom_pair_value(.tail)
  .tail:
    dd rom_pair_value(combination_3)
    dd nil_tag

list_3:
    dd rom_pair_value(combination_1)
    dd rom_pair_value(.tail_1)
  .tail_1:
    dd rom_pair_value(combination_2)
    dd rom_pair_value(.tail_2)
  .tail_2:
    dd rom_pair_value(combination_3)
    dd nil_tag

lisp_rom_limit:
