%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory      equ 0xDEAD0010
err_internal_error          equ 0xDEAD0020
err_not_a_number            equ 0xDEAD0030
err_not_implemented         equ 0xDEAD0040
private_lookup_table_length equ 0

rn_get_blob_data:
    call fail
    ret
rn_error:
    call fail
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/list-metrics.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"
%include "runtime/bigints.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call init_lisp_heap
    call test_negative_fixint_constants
    call test_extension_macro
    call test_adc_macro
    call test_normalize_fix
    call test_normalize_shrink
    call test_normalize_keep

    call init_lisp_heap
    call test_fix_fix_fix
    call test_fix_fix_big
    call test_big_big

    call test_neg_fix
    call test_neg_big

    call test_selected
    jmp test_finished

test_negative_fixint_constants:
    mov eax, fixint_value(-1)
    cmp eax, 0xFFFFFFFD
    call pass_if.z
    mov eax, fixint_value(min_fixint)
    cmp eax, 0x80000001
    call pass_if.z
    ret

test_extension_macro:
    call next_subtest
%macro check_extension 2
    mov eax, fixint_value(%1)
    bigint_extension eax
    cmp eax, fixint_value(%2)
    call pass_if.z
%endmacro
    check_extension 0, 0
    check_extension 1, 0
    check_extension 12345, 0
    check_extension max_fixint, 0
    check_extension -1, -1
    check_extension -2, -1
    check_extension -12345, -1
    check_extension min_fixint, -1
    ret

test_adc_macro:
    call next_subtest
%macro check_adc 5
    mov eax, fixint_value(%1)
    mov ebx, fixint_value(%2)
    mov ecx, %3
    fixint_adc
    cmp eax, fixint_value(%4)
    call pass_if.z
    cmp ecx, %5
    call pass_if.z
%endmacro
    check_adc 0, 0, 0,  0, 0
    check_adc 1, 0, 0,  1, 0
    check_adc 0, 1, 0,  1, 0
    check_adc 1, 1, 0,  2, 0
    check_adc 0, 0, 1,  1, 0
    check_adc 1, 0, 1,  2, 0
    check_adc 0, 1, 1,  2, 0
    check_adc 1, 1, 1,  3, 0

    check_adc max_fixint,  0, 0,      max_fixint, 0
    check_adc 0,  max_fixint, 0,      max_fixint, 0
    check_adc max_fixint,  1, 0,      min_fixint, 0
    check_adc 1,  max_fixint, 0,      min_fixint, 0
    check_adc max_fixint, -1, 0,  max_fixint - 1, 1
    check_adc -1, max_fixint, 0,  max_fixint - 1, 1

    check_adc max_fixint,  0, 1,      min_fixint, 0
    check_adc 0,  max_fixint, 1,      min_fixint, 0
    check_adc max_fixint,  1, 1,  min_fixint + 1, 0
    check_adc 1,  max_fixint, 1,  min_fixint + 1, 0
    check_adc max_fixint, -1, 1,      max_fixint, 1
    check_adc -1, max_fixint, 1,      max_fixint, 1

    check_adc min_fixint,  0, 0,      min_fixint, 0
    check_adc 0,  min_fixint, 0,      min_fixint, 0
    check_adc min_fixint,  1, 0,  min_fixint + 1, 0
    check_adc 1,  min_fixint, 0,  min_fixint + 1, 0
    check_adc min_fixint, -1, 0,      max_fixint, 1
    check_adc -1, min_fixint, 0,      max_fixint, 1
    ret

test_normalize_fix:
    call next_subtest
%macro check_nrm_fix 2
    push dword fixint_value(%2)
    push dword fixint_value(%2)
    push dword fixint_value(%1)
    push dword bigint_header(4)
    mov ebx, esp
    mov eax, 123456
    mov ecx, 234567
    call bi_normalize
    cmp eax, fixint_value(%1)
    call pass_if.z
    push dword fixint_value(%2)
    push dword fixint_value(%2)
    push dword fixint_value(%2)
    push dword fixint_value(%2)
    push dword fixint_value(%1)
    push dword bigint_header(6)
    mov ebx, esp
    mov eax, 234567
    mov ecx, 345678
    call bi_normalize
    cmp eax, fixint_value(%1)
    call pass_if.z
    add esp, 40
%endmacro
    check_nrm_fix 0, 0
    check_nrm_fix 1, 0
    check_nrm_fix 1234, 0
    check_nrm_fix max_fixint, 0
    check_nrm_fix -1, -1
    check_nrm_fix -12456, -1
    check_nrm_fix -min_fixint, -1
    ret

test_normalize_shrink:
    call next_subtest
%macro check_nrm_shrink 4
    mov dword [lisp_heap_pointer], 0xDEADBEEF
    push dword fixint_value(%4)
    push dword fixint_value(%4)
    push dword fixint_value(%3)
    push dword fixint_value(%2)
    push dword fixint_value(%1)
    push dword bigint_header(6)
    mov ebx, esp
    mov eax, 234567
    mov ecx, 345678
    call bi_normalize
    cmp eax, esp
    call pass_if.z
    cmp [esp], dword bigint_header(4)
    call pass_if.z
    cmp [esp + 4], dword fixint_value(%1)
    call pass_if.z
    cmp [esp + 8], dword fixint_value(%2)
    call pass_if.z
    cmp [esp + 12], dword fixint_value(%3)
    call pass_if.z
    cmp dword [lisp_heap_pointer], 0xDEADBEEF
    call pass_if.z
    add esp, 24
    push dword fixint_value(%4)
    push dword fixint_value(%4)
    push dword fixint_value(%3)
    push dword fixint_value(%2)
    push dword fixint_value(%1)
    push dword bigint_header(6)
    mov ebx, esp
    mov eax, 234567
    mov ecx, 345678
    lea edx, [esp + 24]
    mov dword [lisp_heap_pointer], edx
    mov ecx, 456789
    call bi_normalize
    cmp eax, esp
    call pass_if.z
    cmp [eax], dword bigint_header(4)
    call pass_if.z
    lea edx, [esp + 16]
    cmp dword [lisp_heap_pointer], edx
    call pass_if.z
    add esp, 24
%endmacro
    check_nrm_shrink  0, 1, 0, 0
    check_nrm_shrink -1, 0, 0, 0
    check_nrm_shrink  0, 1,-1,-1
    check_nrm_shrink  0,-1,-1,-1
    ret

test_normalize_keep:
    call next_subtest
%macro check_nrm_keep 3
    push dword fixint_value(%3)
    push dword fixint_value(%2)
    push dword fixint_value(%1)
    push dword bigint_header(4)
    mov ebx, esp
    mov eax, 234567
    mov ecx, 345678
    call bi_normalize
    cmp eax, esp
    call pass_if.z
    cmp [esp], dword bigint_header(4)
    call pass_if.z
    cmp [esp + 4], dword fixint_value(%1)
    call pass_if.z
    cmp [esp + 8], dword fixint_value(%2)
    call pass_if.z
    cmp [esp + 12], dword fixint_value(%3)
    call pass_if.z
    add esp, 16
%endmacro
    check_nrm_keep 0, 1, 2
    check_nrm_keep 0, 0, 3
    check_nrm_keep 0, 4, 0
    check_nrm_keep 0, -1, -1
    check_nrm_keep -1, -1, 5
    check_nrm_keep -1, 6, -1
    ret

test_fix_fix_fix:
    call next_subtest
%macro check_fff 3
    mov ebx, fixint_value(%1)
    mov ecx, fixint_value(%2)
    call rn_fixint_plus_fixint
    cmp eax, fixint_value(%3)
    call pass_if.z
%endmacro
    check_fff 0, 0, 0
    check_fff 123, 456, 579
    check_fff -1, -1, -2
    check_fff max_fixint - 1, 1, max_fixint
    check_fff max_fixint, 0, max_fixint
    check_fff max_fixint, -1, max_fixint - 1
    check_fff min_fixint, 0, min_fixint
    check_fff min_fixint, 1, min_fixint + 1
    ret

test_fix_fix_big:
    call next_subtest
%macro check_ffb 5
    mov ebx, fixint_value(%1)
    mov ecx, fixint_value(%2)
    call rn_fixint_plus_fixint
    test al, 3
    call pass_if.z
    cmp [eax], dword bigint_header(4)
    call pass_if.z
    cmp [eax + 4], dword fixint_value(%3)
    call pass_if.z
    cmp [eax + 8], dword fixint_value(%4)
    call pass_if.z
    cmp [eax + 12], dword fixint_value(%5)
    call pass_if.z
%endmacro
    check_ffb max_fixint, max_fixint, -2, 0, 0
    check_ffb max_fixint, 1,          min_fixint, 0, 0
    check_ffb max_fixint, 2,          min_fixint+1, 0, 0
    check_ffb min_fixint, min_fixint, 0, -1, -1
    check_ffb min_fixint, -1,         max_fixint, -1, -1
    check_ffb min_fixint, -2,         max_fixint-1, -1, -1
    ret

big_of_64:
    push ebx
    push ecx
    push edx
    mov ecx, 4
    call rn_allocate
    lea ebx, [4 * edi + 1]
    shrd edi, esi, 30
    shr esi, 30
    lea ecx, [4 * edi + 1]
    shrd edi, esi, 30
    lea edx, [4 * edi + 1]
    mov [eax + bigint.header], dword bigint_header(4)
    mov [eax + bigint.digit0], ebx
    mov [eax + bigint.digit1], ecx
    mov [eax + bigint.digit2], edx
    pop edx
    pop ecx
    pop ebx
    ret

big_to_64:
    test al, 3
    jz .big
  .fix:
    push ecx
    mov ecx, eax
    xor cl, 1
    test cl, 3
    call pass_if.z
    shr ecx, 2
    mov edi, ecx
    xor esi, esi
    pop ecx
    ret
  .big:
    push eax
    push ecx
    xor esi, esi
    xor edi, edi
    ;;
    mov eax, [ebx + bigint.digit2]
    mov ecx, eax
    xor cl, 1
    test cl, 3
    call pass_if.z
    shr eax, 2
    or edi, eax
    shld esi, edi, 30
    shl edi, 30
    ;;
    mov eax, [ebx + bigint.digit1]
    mov ecx, eax
    xor cl, 1
    test cl, 3
    call pass_if.z
    shr eax, 2
    or edi, eax
    shld esi, edi, 30
    shl edi, 30
    ;;
    mov eax, [ebx + bigint.digit0]
    mov ecx, eax
    xor cl, 1
    test cl, 3
    call pass_if.z
    shr eax, 2
    or edi, eax
    pop ecx
    pop eax
    ret

test_big_big:
    call next_subtest
%macro test_64 6
    mov esi, %1
    mov edi, %2
    call big_of_64
    mov ebx, eax
    mov esi, %3
    mov edi, %4
    call big_of_64
    mov ecx, eax
    mov eax, 0x123456
    mov esi, 0x123456
    mov edi, 0x123456
    mov ebp, 0x123456
    push ebx
    push ecx
    call rn_bigint_plus_bigint
    pop ebx
    pop ecx
    cmp eax, ebx
    call pass_if.nz
    cmp eax, ecx
    call pass_if.nz
    mov ebx, eax
    call big_to_64
    cmp esi, %5
    call pass_if.z
    cmp edi, %6
    call pass_if.z
%endmacro
    test_64 0x00000000, 0x00000000, \
            0x00000000, 0x00000000, \
            0x00000000, 0x00000000
    test_64 0x00000000, 0x00001234, \
            0x00000000, 0x00000000, \
            0x00000000, 0x00001234
    test_64 0x00000000, 0x00000000, \
            0x00000000, 0x00004567, \
            0x00000000, 0x00004567
    test_64 0x00000000, 0x00001234, \
            0x00000000, 0x00004567, \
            0x00000000, 0x0000579b
    test_64 0x00000000, 0x3456789A, \
            0x00000000, 0x789ABCDE, \
            0x00000000, 0xACF13578
    test_64 0x00001234, 0x56789ABC, \
            0x00000000, 0x00543210, \
            0x00001234, 0x56CCCCCC
    test_64 0xFFFFFFFF, 0xFFFFFFFF, \
            0xFFFFFFFF, 0xFFFFFFFF, \
            0xFFFFFFFF, 0xFFFFFFFE
    test_64 0xFFFFF050, 0x6FE43210, \
            0xFFFFFFFF, 0xFFFFFF80, \
            0xFFFFF050, 0x6FE43190
    test_64 0xFFFFFFFF, 0xE0000000, \
            0xFFFFFFFF, 0xFFFFFFFF, \
            0xFFFFFFFF, 0xDFFFFFFF
    test_64 0xFFFFFFFF, 0xDFFFFFFF, \
            0x00000000, 0x00000001, \
            0xFFFFFFFF, 0xE0000000
    ret

test_neg_fix:
    call next_subtest
%macro check_negff 2
    mov ebx, fixint_value(%1)
    call rn_negate_fixint
    cmp eax, fixint_value(%2)
    call pass_if.z
%endmacro
    check_negff 0, 0
    check_negff 1, -1
    check_negff -1, 1
    check_negff 2, -2
    check_negff -2, 2
    check_negff -32131, 32131
    check_negff 543329, -543329
    check_negff max_fixint, (- max_fixint)
    check_negff (- max_fixint), max_fixint
    mov ebx, fixint_value(min_fixint)
    call rn_negate_fixint
    test al, 3
    call pass_if.z
    cmp [eax], dword bigint_header(4)
    call pass_if.z
    cmp [eax + bigint.digit0], dword fixint_value(min_fixint)
    call pass_if.z
    cmp [eax + bigint.digit1], dword fixint_value(0)
    call pass_if.z
    cmp [eax + bigint.digit2], dword fixint_value(0)
    call pass_if.z
    ret

test_neg_big:
    call next_subtest
%macro check_neg_64 4
    mov esi, %1
    mov edi, %2
    call big_of_64
    mov ebx, eax
    mov esi, 0x123456
    mov edi, 0x123456
    mov ebp, 0x123456
    push ebx
    call rn_negate_bigint
    pop ebx
    cmp eax, ebx
    call pass_if.nz
    mov ebx, eax
    call big_to_64
    cmp esi, %3
    call pass_if.z
    cmp edi, %4
    call pass_if.z
%endmacro
    check_neg_64 0x00000000, 0x87654321, \
                 0xFFFFFFFF, 0x789ABCDF
    check_neg_64 0xFFFFFF00, 0x00000000, \
                 0x00000100, 0x00000000

    mov ebx, bigint_boundary_90
    call rn_negate_bigint
    cmp eax, fixint_value(min_fixint)
    call pass_if.z

    mov ebx, bigint_negative_90
    push ebx
    call rn_negate_bigint
    pop ebx
    cmp eax, ebx
    call pass_if.nz
    test al, 3
    call pass_if.z
    cmp [eax], dword bigint_header(6)
    call pass_if.z
    cmp [eax + bigint.digit0], dword fixint_value(0)
    call pass_if.z
    cmp [eax + bigint.digit1], dword fixint_value(0)
    call pass_if.z
    cmp [eax + bigint.digit2], dword fixint_value(min_fixint)
    call pass_if.z
    cmp [eax + bigint.digit3], dword fixint_value(0)
    call pass_if.z
    cmp [eax + bigint.digit4], dword fixint_value(0)
    call pass_if.z
    ret

test_selected:
    mov ebx, bigint_2684354560
    call rn_negate_bigint
    mov ebx, eax
    mov ecx, bigint_m2684354560
    rn_trace 1, 'neg', lisp, ebx, lisp, ecx
    call rn_integer_compare
    test eax, eax
    call pass_if.z

    mov ebx, bigint_2882400001
    mov ecx, bigint_m2684354560
    call rn_bigint_plus_bigint
    cmp eax, fixint_value(198045441)
    call pass_if.z
    ret

section .lisp_rom
    align 8
lisp_rom_base:

bigint_negative_90:
    dd bigint_header(4)
    dd fixint_value(0)
    dd fixint_value(0)
    dd fixint_value(min_fixint)

bigint_boundary_90:
    dd bigint_header(4)
    dd fixint_value(min_fixint)
    dd fixint_value(0)
    dd fixint_value(0)

bigint_2882400001:
    dd bigint_header(4)
    dd fixint_value(734916353)
    dd fixint_value(2)
    dd fixint_value(0)

bigint_m2684354560:
    dd bigint_header(4)
    dd fixint_value(536870912)
    dd fixint_value(-3)
    dd fixint_value(-1)

bigint_2684354560:
    dd bigint_header(4)
    dd fixint_value(536870912)
    dd fixint_value(2)
    dd fixint_value(0)


lisp_rom_limit:
