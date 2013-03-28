%include "macros.inc"
%include "testenv.asm"

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
err_match_failure               equ 0xDEAD1100
rom_string_Ssequence            equ 0x00DEAD12

private_lookup_table_length     equ 0
ground_lookup_table_length      equ 0

program_segment_base:
rn_error:
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/list-metrics.asm"
%include "runtime/blob-data.asm"
%include "runtime/environment-lookup.asm"
%include "runtime/environment-mutations.asm"
%include "runtime/mark-bits.asm"
%include "runtime/parameter-trees.asm"
%include "runtime/evaluator.asm"
%include "runtime/interpreted-operatives.asm"

    align 4
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_alloc_env
    ;call test_alloc_noenv
    jmp test_finished

test_alloc_env:
    mov ebx, nil_tag
    mov ecx, symbol_value(1)
    mov edx, rom_pair_value(list_symbol_1)
    mov edi, dummy_environment
    call rn_allocate_closure
    test eax, 3
    call pass_if.z
    cmp [eax + operative.header], dword operative_header(8)
    call pass_if.z
    cmp [eax + operative.program], dword operate_interpreted.env
    call pass_if.z
    cmp [eax + operative.var0], dword dummy_environment
    call pass_if.z
    cmp [eax + operative.var1], dword nil_tag
    call pass_if.z
    cmp [eax + operative.var2], dword symbol_value(1)
    call pass_if.z
    cmp [eax + operative.var3], dword rom_pair_value(list_symbol_1)
    call pass_if.z
    cmp [eax + operative.var4], dword inert_tag
    call pass_if.z
    cmp [eax + operative.var5], dword inert_tag
    call pass_if.z
    cmp edi, dummy_environment
    call pass_if.z
    push eax
    push dword nil_tag
    call rn_cons
    mov ebx, eax
    mov edi, 0xEEEE0200
    mov ebp, .cont_obj
    jmp rn_eval
  .cont:
    cmp eax, 0xEEEE0200
    call pass_if.z
    ret
    align 4
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd .cont_obj
    dd 0

test_primitive:
    add eax, fixint_value(1)
    jmp [ebp + cont.program]

section .lisp_rom
    align 8
lisp_rom_base:

dummy_environment:
    dd environment_header(4)
    dd 0xDEADBEEF
    dd 0xDEADBEEF
    dd 0xDEADBEEF

list_symbol_1:
    dd symbol_value(1)
    dd nil_tag

private_env_object:
    dd 0xDEADBEEF

lisp_rom_limit:
