%include "macros.inc"
%include "testenv.asm"

;; mock

private_lookup_table_length equ 0
ground_lookup_table_length equ 0

err_immutable_environment     equ 0xDEAD0010
err_invalid_argument          equ 0xDEAD0020
err_undefined_private_binding equ 0xDEAD0030
err_out_of_lisp_memory        equ 0xDEAD0040
err_internal_error            equ 0xDEAD0050

rn_get_blob_data:
    call fail
    ret
rn_error:
    call fail
    jmp rn_fatal

    align 4
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/environment-lookup.asm"
%include "runtime/environment-mutations.asm"

    align 4
private_env_object:
    dd environment_header(2)
    dd private_env_lookup

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_make_env
    jmp test_finished

test_make_env:
    call next_subtest
    mov ebx, private_env_object
    call rn_make_list_environment
    test al, 3
    call pass_if.z
    mov ebx, [eax]
    cmp bl, environment_header(0)
    call pass_if.z

    mov edi, eax
    mov ebx, symbol_value(1)
    push .fail1
    push edi
    mov ebp, .cont1_obj
    jmp [edi + environment.program]
  .fail1:
    call pass
    cmp ebx, symbol_value(1)
    call pass_if.z
    mov eax, symbol_value(1)
    mov ebx, fixint_value(2)
    call rn_mutate_environment
    
    mov ebx, eax
    push .fail2
    push edi
    mov ebp, .cont2_obj
    jmp [edi + environment.program]
  .fail2:
    call fail
    ret
  .cont2:
    cmp eax, fixint_value(2)
    call pass_if.z
    cmp ebp, .cont2_obj
    call pass_if.z
    ret
  .cont1:
    jmp fail

    align 4
  .cont1_obj:
    dd cont_header(2)
    dd .cont1
  .cont2_obj:
    dd cont_header(2)
    dd .cont2

section .lisp_rom
    align 8
lisp_rom_base:
lisp_rom_limit:
