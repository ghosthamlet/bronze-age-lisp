%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory          equ 0xDEAD0030
err_out_of_blob_memory          equ 0xDEAD0040
err_internal_error              equ 0xDEAD0050
err_invalid_blob_heap_operation equ 0xDEAD0060
err_invalid_argument_structure  equ 0xDEAD0070
private_lookup_table_length     equ 0

rn_get_blob_data:
rn_asm_applicative:
  .L11:
    call fail
    ret
rn_out_of_memory:
rn_error:
    jmp rn_fatal

ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/mark-bits.asm"
%include "modules/shared-structures.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_visit
    call test_explore
    call test_package
    jmp test_finished

get_mark_value:
    call rn_mark_base_32
    call rn_mark_index
    mov eax, [esi + 4 * eax]
    ret

set_mark_value:
    call rn_mark_base_32
    call rn_mark_index
    mov [esi + 4 * eax], ecx
    ret

test_visit:
    call rn_clear_mark_bits
    call rn_mark_base_32
    mov edi, esi              ; EDI = base of 32-bit mark values
    call rn_mark_base_1       ; ESI = base of 1-bit marks
    push edi
    push esi
    mov ebp, nil_tag
    mov eax, 3                ; invalid
    mov ebx, 0x1234B000       ; invalid, unit test only
    mov ecx, 0x1234C000
    mov edx, 0x1234D000
    call sh_visit
    call pass_if.z
    cmp eax, 3
    call pass_if.z
    cmp ebx, 0x1234B000
    call pass_if.z
    cmp ebp, nil_tag
    pop edx
    cmp edx, esi
    call pass_if.z
    pop edx
    cmp edx, edi
    call pass_if.z
    mov edx, [esi]
    cmp edx, (1 << 3)
    call pass_if.z
    cmp [edi + 3*4], dword 0
    call pass_if.z

    call sh_visit
    call pass_if.nz
    cmp eax, 3
    call pass_if.z
    cmp ebx, 0x1234B000
    call pass_if.z
    cmp ebp, 0x1234B000
    call pass_if.z
    cmp [edi + 3*4], dword nil_tag
    call pass_if.z

    call sh_visit
    call pass_if.nz
    cmp eax, 3
    call pass_if.z
    cmp ebx, 0x1234B000
    call pass_if.z
    cmp ebp, 0x1234B000
    call pass_if.z
    cmp [edi + 3*4], dword nil_tag
    call pass_if.z

    call sh_visit
    call pass_if.nz
    call sh_visit
    call pass_if.nz
    call sh_visit
    call pass_if.nz
    ret

test_explore:
    call next_subtest

    mov ebx, fixint_value(1234)
    mov ebp, nil_tag
    call sh_explore
    cmp ebx, fixint_value(1234)
    call pass_if.z
    cmp ebp, nil_tag
    call pass_if.z

    mov ebx, dummy_applicative
    mov ebp, nil_tag
    call sh_explore
    cmp ebx, dummy_applicative
    call pass_if.z
    cmp ebp, nil_tag
    call pass_if.z

    mov ebx, rom_pair_value(list_1)
    mov ebp, nil_tag
    call sh_explore
    cmp ebp, nil_tag
    call pass_if.z

    mov ebx, rom_pair_value(list_2)
    mov ebp, nil_tag
    call sh_explore
    cmp ebp, nil_tag
    call pass_if.z

    mov ebx, rom_pair_value(cycle_1)
    mov ebp, nil_tag
    call sh_explore
    cmp ebp, rom_pair_value(cycle_1)
    call pass_if.z
    mov ebx, rom_pair_value(cycle_1)
    call get_mark_value
    cmp eax, nil_tag
    call pass_if.z

    mov ebx, rom_pair_value(cycle_2a)
    mov ebp, nil_tag
    call sh_explore
    cmp ebp, rom_pair_value(cycle_2a)
    call pass_if.z
    mov ebx, rom_pair_value(cycle_2a)
    call get_mark_value
    cmp eax, nil_tag
    call pass_if.z

    mov ebx, test_vector
    mov ebp, nil_tag
    call sh_explore
    cmp ebp, rom_pair_value(list_2)
    call pass_if.z
    mov ebx, rom_pair_value(list_2)
    call get_mark_value
    cmp eax, test_vector
    call pass_if.z
    mov ebx, test_vector
    call get_mark_value
    cmp eax, nil_tag
    call pass_if.z
    ret

test_package:
    call next_subtest

    call rn_mark_base_32
    mov edi, esi              ; EDI = base of 32-bit mark values
    mov ebx, nil_tag
    call sh_package
    cmp esi, edi
    call pass_if.z
    call rn_mark_base_32
    cmp esi, edi
    call pass_if.z

    test al, 3
    call pass_if.z
    cmp dword [eax], operative_header(2)
    call pass_if.z
    cmp dword [eax + operative.program], sh_find.empty.operate
    call pass_if.z

    mov ebx, rom_pair_value(list_1)
    mov ecx, nil_tag
    call set_mark_value
    mov ebx, rom_pair_value(list_1)
    call sh_package
    cmp esi, edi
    call pass_if.z
    call rn_mark_base_32
    cmp esi, edi
    call pass_if.z

    test al, 3
    call pass_if.z
    cmp dword [eax], operative_header(4)
    call pass_if.z
    cmp dword [eax + operative.program], sh_find.nonempty.operate
    call pass_if.z
    cmp dword [eax + operative.var0], unbound_tag
    call pass_if.z
    cmp dword [eax + operative.var1], rom_pair_value(list_1)
    call pass_if.z

    mov ebx, rom_pair_value(list_1)
    mov ecx, rom_pair_value(list_2)
    call set_mark_value
    mov ebx, rom_pair_value(list_2)
    mov ecx, nil_tag
    call set_mark_value
    mov ebx, rom_pair_value(list_1)
    call sh_package
    cmp esi, edi
    call pass_if.z
    call rn_mark_base_32
    cmp esi, edi
    call pass_if.z
    test al, 3
    call pass_if.z
    cmp dword [eax], operative_header(4)
    call pass_if.z
    cmp dword [eax + operative.program], sh_find.nonempty.operate
    call pass_if.z
    cmp dword [eax + operative.var0], rom_pair_value(list_2)
    call pass_if.z
    cmp dword [eax + operative.var1], rom_pair_value(list_1)
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

cycle_1:
    dd fixint_value(1)
    dd rom_pair_value(cycle_1)

cycle_2a:
    dd fixint_value(2)
    dd rom_pair_value(cycle_2b)
cycle_2b:
    dd fixint_value(3)
    dd rom_pair_value(cycle_2a)

test_vector:
    dd vector_header(4)
    dd rom_pair_value(list_2)
    dd rom_pair_value(list_2)
    dd test_vector

dummy_applicative:
    dd applicative_header(4)
    dd cycle_2a
    dd cycle_2b
    dd cycle_2a

lisp_rom_limit: