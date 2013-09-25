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
    call test_0
    call test_1
    call test_2
    jmp test_finished

eval_it:
    xor eax, eax
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    mov edi, dummy_env
    mov ebp, .cont_obj
    jmp rn_eval
  .cont:
    ret
  .cont_obj:
    dd cont_header(4)
    dd .cont
    dd 0xDEADBEEF
    dd 0xDEADBEEF

%macro t_eval 2
    mov ebx, rom_pair_value(%1)
    call eval_it
    cmp eax, fixint_value(%2)
    call pass_if.z
%endmacro

test_0:
    t_eval c_o00_0, 0xE000
    t_eval c_o01_0, 0xE010
    t_eval c_a00_0, 0xA000
    t_eval c_a01_0, 0xA010
    ret

test_1:
    t_eval c_o11_1, 0xE111
    t_eval c_o12_1, 0xE121
    t_eval c_a11_1, 0xA111
    t_eval c_a12_1, 0xA121
    ret

test_2:
    t_eval c_o22_2, 0xE222
    t_eval c_o23_2, 0xE232
    t_eval c_a22_2, 0xA222
    t_eval c_a23_2, 0xA232
    ret

ope_000:
    mov eax, fixint_value(0xE000)
    jmp [ebp + cont.program]
ope_010:
    mov eax, fixint_value(0xE010)
    jmp [ebp + cont.program]
ope_011:
    mov eax, fixint_value(0xE011)
    jmp [ebp + cont.program]
ope_111:
    mov eax, fixint_value(0xE111)
    jmp [ebp + cont.program]
ope_121:
    mov eax, fixint_value(0xE121)
    jmp [ebp + cont.program]
ope_122:
    mov eax, fixint_value(0xE122)
    jmp [ebp + cont.program]
ope_222:
    mov eax, fixint_value(0xE222)
    jmp [ebp + cont.program]
ope_232:
    cmp ebx, fixint_value(1)
    call pass_if.z
    cmp ecx, fixint_value(2)
    call pass_if.z
    mov eax, fixint_value(0xE232)
    jmp [ebp + cont.program]
ope_233:
    mov eax, fixint_value(0xE233)
    jmp [ebp + cont.program]

app_000:
    mov eax, fixint_value(0xA000)
    jmp [ebp + cont.program]
app_010:
    mov eax, fixint_value(0xA010)
    jmp [ebp + cont.program]
app_011:
    mov eax, fixint_value(0xA011)
    jmp [ebp + cont.program]
app_111:
    mov eax, fixint_value(0xA111)
    jmp [ebp + cont.program]
app_121:
    mov eax, fixint_value(0xA121)
    jmp [ebp + cont.program]
app_122:
    mov eax, fixint_value(0xA122)
    jmp [ebp + cont.program]
app_222:
    mov eax, fixint_value(0xA222)
    jmp [ebp + cont.program]
app_232:
    cmp ebx, fixint_value(1)
    call pass_if.z
    cmp ecx, fixint_value(2)
    call pass_if.z
    mov eax, fixint_value(0xA232)
    jmp [ebp + cont.program]
app_233:
    mov eax, fixint_value(0xA233)
    jmp [ebp + cont.program]

section .lisp_rom
    align 8
lisp_rom_base:

dummy_env:
    dd environment_header(4)
    dd 0xDEADBEEF
    dd 0xDEADBEEF
    dd 0xDEADBEEF

o_00:
    dd operative_header(2)
    dd rn_asm_operative.L00
    dd ope_000
a_00:
    dd applicative_header(4)
    dd rn_asm_applicative.L00
    dd o_00
    dd app_000

o_01:
    dd operative_header(4)
    dd rn_asm_operative.L01
    dd ope_010
    dd ope_011
    dd 0
a_01:
    dd applicative_header(6)
    dd rn_asm_applicative.L00
    dd o_01
    dd app_010
    dd app_011
    dd 0

o_11:
    dd operative_header(2)
    dd rn_asm_operative.L11
    dd ope_111
a_11:
    dd applicative_header(4)
    dd rn_asm_applicative.L11
    dd o_11
    dd app_111

o_12:
    dd operative_header(4)
    dd rn_asm_operative.L12
    dd ope_121
    dd ope_122
    dd 0
a_12:
    dd applicative_header(6)
    dd rn_asm_applicative.L12
    dd o_12
    dd app_121
    dd app_122
    dd 0

o_22:
    dd operative_header(2)
    dd rn_asm_operative.L22
    dd ope_222
a_22:
    dd applicative_header(4)
    dd rn_asm_applicative.L22
    dd o_22
    dd app_222

o_23:
    dd operative_header(4)
    dd rn_asm_operative.L23
    dd ope_232
    dd ope_233
    dd 0
a_23:
    dd applicative_header(6)
    dd rn_asm_applicative.L23
    dd o_23
    dd app_232
    dd app_233
    dd 0

c_o00_0:
    dd o_00
    dd nil_tag
c_o01_0:
    dd o_01
    dd nil_tag
c_o11_1:
    dd o_11
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(1)
    dd nil_tag
c_o12_1:
    dd o_12
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(1)
    dd nil_tag
c_o22_2:
    dd o_22
    dd rom_pair_value(.t1)
  .t1:
    dd fixint_value(1)
    dd rom_pair_value(.t2)
  .t2:
    dd fixint_value(2)
    dd nil_tag
c_o23_2:
    dd o_23
    dd rom_pair_value(.t1)
  .t1:
    dd fixint_value(1)
    dd rom_pair_value(.t2)
  .t2:
    dd fixint_value(2)
    dd nil_tag

c_a00_0:
    dd a_00
    dd nil_tag
c_a01_0:
    dd a_01
    dd nil_tag

c_a11_1:
    dd a_11
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(1)
    dd nil_tag
c_a12_1:
    dd a_12
    dd rom_pair_value(.tail)
  .tail:
    dd fixint_value(1)
    dd nil_tag

c_a22_2:
    dd a_22
    dd rom_pair_value(.t1)
  .t1:
    dd fixint_value(1)
    dd rom_pair_value(.t2)
  .t2:
    dd fixint_value(2)
    dd nil_tag
c_a23_2:
    dd a_23
    dd rom_pair_value(.t1)
  .t1:
    dd fixint_value(1)
    dd rom_pair_value(.t2)
  .t2:
    dd fixint_value(2)
    dd nil_tag

lisp_rom_limit:
