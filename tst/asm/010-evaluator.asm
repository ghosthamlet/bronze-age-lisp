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
%include "runtime/evaluator.asm"

    align 4
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_eval_fixint
    call test_eval_nil
    call test_eval_primitive
    call test_eval_operative
    jmp test_finished

test_eval_fixint:
    call next_subtest
    mov ebp, .cont_obj
    mov edi, dummy_env
    xor eax, eax
    mov ebx, fixint_value(123)
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    jmp rn_eval
  .cont:
    cmp eax, fixint_value(123)
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov eax, [transient_limit]
    mov ebx, [lisp_heap_pointer]
    cmp eax, ebx
    call pass_if.z
    ret
    align 4
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd .cont_obj
    dd 0

test_eval_nil:
    call next_subtest
    mov ebp, .cont_obj
    mov edi, dummy_env
    xor eax, eax
    mov ebx, nil_tag
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    jmp rn_eval
  .cont:
    cmp eax, nil_tag
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov eax, [transient_limit]
    mov ebx, [lisp_heap_pointer]
    cmp eax, ebx
    call pass_if.z
    ret
    align 4
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd .cont_obj
    dd 0

test_eval_primitive:
    call next_subtest
    mov ebp, .cont_obj
    mov edi, dummy_env
    xor eax, eax
    mov ebx, rom_pair_value(combination_1)
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    jmp rn_eval
  .cont:
    cmp eax, fixint_value(4242)
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov edi, [lisp_heap_pointer]
    cmp edi, [transient_limit]
    call pass_if.z
    ret
    align 4
  .prim:
    cmp eax, primitive_value(.prim)
    call pass_if.z
    cmp ebx, fixint_value(42)
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov eax, fixint_value(4242)
    jmp [ebp + cont.program]
    align 4
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd .cont_obj
    dd 0
    align 4

test_eval_operative:
    call next_subtest
    mov ebp, .cont_obj
    mov edi, dummy_env
    xor eax, eax
    mov ebx, rom_pair_value(combination_2)
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    jmp rn_eval
  .cont:
    cmp eax, fixint_value(13)
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov edi, [lisp_heap_pointer]
    cmp edi, [transient_limit]
    call pass_if.z
    ret
    align 4
  .opcode:
    cmp eax, .operative
    call pass_if.z
    cmp ebx, rom_pair_value(combination_2.tail)
    call pass_if.z
    cmp ebp, .cont_obj
    call pass_if.z
    mov eax, fixint_value(13)
    jmp [ebp + cont.program]
    align 4
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd .cont_obj
    dd 0
  .operative:
    dd operative_header(4)
    dd .opcode
    dd fixint_value(7)
    dd 0

section .lisp_rom
    align 8
lisp_rom_base:

dummy_env:
    dd environment_header(4)
    dd 0xDEADBEEF
    dd 0xDEADBEEF
    dd 0xDEADBEEF

combination_1:
    dd primitive_value(test_eval_primitive.prim)
    dd fixint_value(42)

combination_2:
    dd test_eval_operative.operative
    dd rom_pair_value(.tail)
  .tail:
    dd ignore_tag
    dd dummy_env

lisp_rom_limit:
