%include "macros.inc"
%include "testenv.asm"

;; mock

err_out_of_lisp_memory      equ 0xDEAD0010
err_internal_error          equ 0xDEAD0020
private_lookup_table_length equ 0

rn_get_blob_data:
    call fail
    ret
rn_out_of_memory:
rn_error:
    call fail
    jmp rn_fatal
ground_private_lookup_table:
    dd 0, 0, 0, 0

%include "runtime/debug.asm"
%include "runtime/list-metrics.asm"
%include "runtime/lisp-garbage.asm"
%include "runtime/lisp-allocator.asm"

    align 4
program_segment_base:
_start:
    mov [stack_limit], esp
    call test_init
    call test_alloc_size
    call test_alloc_sequence
    call test_alloc_place
    call test_preserve
    call test_transient_min
    call test_alloc_transient_replace
    call test_alloc_transient_ebp
    call test_cons_1
    call test_cons_2
    jmp test_finished

test_init:
    mov edi, 0xDEADBEEF
    call init_lisp_heap
    mov edi, [transient_limit]
    cmp edi, [lisp_heap_pointer]
    call pass_if.z
    mov eax, edi
    sub eax, configured_lisp_transient_size
    test eax, configured_lisp_heap_size - 1
    call pass_if.z
    mov eax, edi
    and eax, ~(configured_lisp_heap_size - 1)
    add eax, configured_lisp_heap_size
    cmp edi, eax
    call pass_if.b
    ret

test_alloc_size:
    call next_subtest
    %assign i 2
  %rep 3
    call init_lisp_heap
    push dword [lisp_heap_pointer]
    mov ecx, i
    mov ebx, 0x1234A001
    mov edx, 0x1234B001
    mov esi, 0x1234C001
    mov edi, 0x1234D001
    mov ebp, 0x1234E001
    call rn_allocate
    cmp ebx, 0x1234A001
    call pass_if.z
    cmp edx, 0x1234B001
    call pass_if.z
    cmp esi, 0x1234C001
    call pass_if.z
    cmp edi, 0x1234D001
    call pass_if.z
    cmp ebp, 0x1234E001
    call pass_if.z
    cmp ecx, i
    call pass_if.z
    pop ebx
    cmp eax, ebx
    call pass_if.z
    mov ecx, [lisp_heap_pointer]
    sub ecx, eax
    cmp ecx, (4 * i)
    call pass_if.z
    %assign i (i + 2)
  %endrep
    ret

test_alloc_sequence:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    mov ecx, 16
    call rn_allocate
    push eax
    mov ecx, 6
    call rn_allocate
    push eax
    mov ecx, 2
    call rn_allocate
    mov ecx, eax
    pop ebx
    pop eax
    sub ecx, ebx
    cmp ecx, 6 * 4
    call pass_if.z
    sub ebx, eax
    cmp ebx, 16 * 4
    call pass_if.z
    ret

test_alloc_place:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
  %rep 10
    mov ecx, 32
    call rn_allocate
    mov [eax], dword environment_header(32)
    mov ebx, eax
    mov edi, [lisp_heap_pointer]
    xor ebx, edi
    test ebx, ~(configured_lisp_heap_size - 1)
    call pass_if.z
    xor ebx, ebx
    xor edi, edi
  %endrep
    ret

test_preserve:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp

    mov ecx, 4
    call rn_allocate
    mov [eax +  0], dword environment_header(4)
    mov [eax +  4], dword fixint_value(1)
    mov [eax +  8], dword fixint_value(2)
    mov [eax + 12], dword fixint_value(3)

    push dword boolean_value(0)
    push dword boolean_value(0)
    call rn_cons
    mov ebx, eax

    mov ecx, 6
    call rn_allocate
    mov [eax +  0], dword environment_header(6)
    mov [eax +  4], dword ebx
    mov [eax +  8], dword ebx
    mov [eax + 12], dword fixint_value(6)
    mov [eax + 16], dword fixint_value(7)
    mov [eax + 20], dword fixint_value(8)
    mov edi, eax
    mov esi, edi
    xor esi, 1

    mov ecx, 70
  .L:
    push dword fixint_value(9)
    push dword fixint_value(10)
    call rn_cons
    loop .L

    xor esi, 1
    cmp esi, edi
    call pass_if.nz
    cmp [edi +  0], dword environment_header(6)
    call pass_if.z
    cmp [edi +  4], ebx
    call pass_if.z
    cmp [edi +  8], ebx
    call pass_if.z
    cmp [edi + 12], dword fixint_value(6)
    call pass_if.z
    cmp [edi + 16], dword fixint_value(7)
    call pass_if.z
    cmp [edi + 20], dword fixint_value(8)
    call pass_if.z
    cmp car(eax), dword fixint_value(9)
    call pass_if.z
    cmp car(eax), dword fixint_value(9)
    call pass_if.z
    ret

test_transient_min:
    call next_subtest
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    mov ebp, 0
    mov edi, 0
    call rn_transient_min
    cmp eax, [lisp_heap_pointer]
    call pass_if.z

    mov ebp, [transient_limit]
    sub ebp, 4
    mov edi, 0
    call rn_transient_min
    cmp eax, ebp
    call pass_if.z

    mov ebp, 0
    mov edi, [transient_limit]
    sub edi, 4
    call rn_transient_min
    cmp eax, edi
    call pass_if.z

    ret

test_alloc_transient_replace:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    %assign i 2
    %assign s 0
  %rep 4
    call next_subtest
    xor eax, eax
    mov ebx, 0x1234A001
    mov ecx, (- i)
    mov edx, 0x1234B001
    mov esi, 0x1234C001
    mov edi, 0x00000000
    mov ebp, 0x00000000
    call rn_allocate_transient
    mov [eax], dword cont_header(i)
    cmp ebx, 0x1234A001
    call pass_if.z
    cmp edx, 0x1234B001
    call pass_if.z
    cmp esi, 0x1234C001
    call pass_if.z
    cmp edi, 0x00000000
    call pass_if.z
    cmp ebp, 0x00000000
    call pass_if.z
    cmp ecx, (- i)
    call pass_if.z
    mov ecx, [transient_limit]
    sub ecx, eax
    cmp ecx, (4 * i)
    call pass_if.z
    %assign i (i + 2)
  %endrep

test_alloc_transient_ebp:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
    %assign i 2
    %assign s 0
  %rep 4
    call next_subtest
    mov ecx, (- i)
    mov ebx, 0x1234A001
    mov edx, 0x1234B001
    mov edi, 0x1234C001
    mov esi, 0x00000000
    call rn_allocate_transient
    mov [eax], dword cont_header(i)
    cmp ebx, 0x1234A001
    call pass_if.z
    cmp edx, 0x1234B001
    call pass_if.z
    cmp edi, 0x1234C001
    call pass_if.z
    cmp esi, 0x00000000
    call pass_if.z
    cmp ecx, (- i)
    call pass_if.z
    mov ecx, [transient_limit]
    sub ecx, eax
    cmp ecx, (4 * (s + i))
    call pass_if.z
    mov ebp, eax
    %assign s (s + i)
  %endrep
    ret

test_cons_1:
    call next_subtest
    mov ebx, 0x1234B001
    mov ecx, 0x1234C001
    mov edx, 0x1234D001
    mov edi, 0x1234E001
    mov esi, 0x1234F001
    mov ebp, 0x1234A001
    push dword 0x12340001
    push dword fixint_value(42)
    push dword fixint_value(314)
    call rn_cons
    cmp ebx, 0x1234B001
    call pass_if.z
    cmp ecx, 0x1234C001
    call pass_if.z
    cmp edx, 0x1234D001
    call pass_if.z
    cmp edi, 0x1234E001
    call pass_if.z
    cmp esi, 0x1234F001
    call pass_if.z
    cmp ebp, 0x1234A001
    call pass_if.z
    pop ebx
    cmp ebx, 0x12340001
    call pass_if.z
    test al, 3
    call pass_if.nz
    test al, 3
    call pass_if.p
    mov ebx, car(eax)
    cmp ebx, fixint_value(42)
    call pass_if.z
    mov ebx, cdr(eax)
    cmp ebx, fixint_value(314)
    call pass_if.z
    ret

test_cons_2:
    call next_subtest
    call init_lisp_heap
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    xor ebp, ebp
  %assign n 30
  %rep 4
    push dword fixint_value(n)
    push dword nil_tag
    call rn_cons
    mov edx, eax
    mov eax, nil_tag
    mov ecx, n
  .L%+n:
    push edx
    push eax
    call rn_cons
    loop .L%+n
    mov ebx, car(eax)
    cmp edx, ebx
    call pass_if.z
    mov ebx, car(ebx)
    cmp ebx, fixint_value(n)
    call pass_if.z
    mov ebx, eax
    call rn_list_metrics
    cmp eax, 1
    call pass_if.z
    cmp ecx, 0
    call pass_if.z
    cmp edx, n
    call pass_if.z
    %assign n (n + 1)
  %endrep
    ret

section .lisp_rom
    align 8
lisp_rom_base:
lisp_rom_limit:
