%include "macros.inc"
%include "testenv.asm"

    align 4
program_segment_base:
dummy_label:
_start:
    call test_pair_type
    call next_subtest
    call test_nonpair_type
    call next_subtest
    call test_car_cdr
    call next_subtest
    call test_runtime_pair_tagging
    call next_subtest
    call test_pair_cases_1
    call test_pair_cases_2
    call test_pair_cases_3
    call test_pair_cases_4
    call test_pair_cases_5
    call next_subtest
    call test_bool_cases_1
    call test_bool_cases_2
    call test_bool_cases_3
    call test_bool_cases_4
    jmp test_finished

test_pair_type:
    mov eax, rom_pair_value(pair_object_1)
    test al, 3
    call pass_if.nz
    test al, 3
    call pass_if.p
    cmp al, nil_tag
    call pass_if.nz
    ret

test_nonpair_type:
    mov eax, fixint_value(5)
    test al, 3
    call pass_if.nz
    test al, 3
    call pass_if.np

    mov eax, nil_tag
    test al, 3
    call pass_if.nz
    test al, 3
    call pass_if.np

    mov eax, nonpair_object
    test al, 3
    call pass_if.z
    ret

test_car_cdr:
    mov eax, rom_pair_value(pair_object_1)
    mov ebx, car(eax)
    cmp ebx, inert_tag
    call pass_if.z
    mov ebx, cdr(eax)
    cmp ebx, nil_tag
    call pass_if.z
    mov eax, rom_pair_value(pair_object_2)
    mov ebx, car(eax)
    cmp ebx, fixint_value(1)
    call pass_if.z
    mov ebx, cdr(eax)
    cmp ebx, fixint_value(2)
    call pass_if.z
    mov eax, rom_pair_value(pair_object_3)
    mov ebx, car(eax)
    mov ebx, car(ebx)
    cmp ebx, inert_tag
    call pass_if.z
    mov eax, rom_pair_value(pair_object_3)
    mov ebx, car(eax)
    mov ebx, cdr(ebx)
    cmp ebx, nil_tag
    call pass_if.z
    mov eax, rom_pair_value(pair_object_3)
    mov ebx, cdr(eax)
    mov ebx, car(ebx)
    cmp ebx, fixint_value(1)
    call pass_if.z
    mov eax, rom_pair_value(pair_object_3)
    mov ebx, cdr(eax)
    mov ebx, cdr(ebx)
    cmp ebx, fixint_value(2)
    call pass_if.z
    ret

test_runtime_pair_tagging:
    mov eax, pair_object_1
    load_immutable_pair ebx, eax
    mov ecx, rom_pair_value(pair_object_1)
    cmp ebx, ecx
    call pass_if.z

    mov eax, pair_object_1
    load_mutable_pair ebx, eax
    test bl, 3
    call pass_if.nz
    test bl, 3
    call pass_if.p
    ret

test_pair_cases_1:
    mov ebx, boolean_value(1)
    pair_nil_cases
    jmp pass
  .case.pair:
  .case.nil:
    jmp fail

test_pair_cases_2:
    mov ebx, nonpair_object
    pair_nil_cases
    jmp pass
  .case.pair:
  .case.nil:
    jmp fail

test_pair_cases_3:
    mov ebx, rom_pair_value(pair_object_1)
    pair_nil_cases
    jmp fail
  .case.pair:
    jmp pass
  .case.nil:
    jmp fail

test_pair_cases_4:
    mov eax, pair_object_1
    load_mutable_pair ebx, eax
    pair_nil_cases
    jmp fail
  .case.pair:
    jmp pass
  .case.nil:
    jmp fail

test_pair_cases_5:
    mov ebx, nil_tag
    pair_nil_cases
  .case.pair:
    jmp fail
  .case.nil:
    jmp pass

test_bool_cases_1:
    mov ebx, boolean_value(0)
    bool_cases
    jmp fail
  .case.true:
    jmp fail
  .case.false:
    jmp pass

test_bool_cases_2:
    mov ebx, boolean_value(1)
    bool_cases
    jmp fail
  .case.true:
    jmp pass
  .case.false:
    jmp fail

test_bool_cases_3:
    mov ebx, rom_pair_value(pair_object_1)
    bool_cases
    jmp pass
  .case.true:
    jmp fail
  .case.false:
    jmp fail

test_bool_cases_4:
    mov ebx, fixint_value(1)
    bool_cases
    jmp pass
  .case.true:
  .case.false:
    jmp fail

section .lisp_rom
    align 8
lisp_rom_base:
pair_object_1:
    dd inert_tag
    dd nil_tag
pair_object_2:
    dd fixint_value(1)
    dd fixint_value(2)
pair_object_3:
    dd rom_pair_value(pair_object_1)
    dd rom_pair_value(pair_object_2)
nonpair_object:
    dd environment_header(4)
    dd 0
    dd 0
    dd 0
