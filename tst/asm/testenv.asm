%macro push_abcd 0
    push eax
    push ebx
    push ecx
    push edx
%endmacro

%macro pop_dcba 0
    pop edx
    pop ecx
    pop ebx
    pop eax
%endmacro

section .data

testenv_fail dd 0
testenv_pass dd 0
testenv_buffer times 16 db 0
testenv_buffer_end:

blob_descriptors:
  ;dd rom_string_0,   1
  ;dd rom_string_end, 1
.ram: times 42 dq 0
.limit:

section .rodata:
rom_string_0: db "rom-string"
rom_string_end:

section .bss
    align 4
test_buffer resb 1024
test_buffer_end: resd 32
%include "runtime/bss.asm"

section .text
    global _start, pass_if.z, pass_if.nz, pass, fail, next_subtest, test_finished

pass_if:
  .z:
    push_abcd
    setz al
    movzx ebx, al
    jmp .account
  .nz:
    push_abcd
    setnz al
    movzx ebx, al
    jmp .account
  .p:
    push_abcd
    setp al
    movzx ebx, al
    jmp .account
  .np:
    push_abcd
    setnp al
    movzx ebx, al
    jmp .account
  .b:
    push_abcd
    setb al
    movzx ebx, al
    jmp .account
  .account:
    mov eax, [testenv_fail + 4 * ebx]
    add eax, 1
    mov [testenv_fail + 4 * ebx], eax
%ifdef VERBOSE
    mov eax,ebx
    add eax, '0'
    call print_char
%endif
    pop_dcba
    ret

pass:
    push_abcd
    mov ebx, 1
    jmp pass_if.account
fail:
    push_abcd
    mov ebx, 0
    jmp pass_if.account

next_subtest:
%ifdef VERBOSE
    push eax
    mov al, '_'
    call print_char
    pop eax
%endif
    ret

test_finished:
    mov al, ' '
    call print_char
    mov eax, [testenv_pass]
    call print_decimal
    mov al, '/'
    call print_char
    mov eax, [testenv_pass]
    add eax, [testenv_fail]
    call print_decimal
    mov al, 10
    call print_char
    mov eax, 1
    mov ebx, 0
    int 0x80

print_decimal:
    push_abcd
    mov ebx, 10
    lea ecx, [testenv_buffer_end]
  .next_digit:
    xor edx, edx
    div ebx
    add dl, '0'
    dec ecx
    mov [ecx], dl
    test eax, eax
    jnz .next_digit
  .done:
    mov eax, 4
    mov ebx, 1
    mov edx, testenv_buffer_end
    sub edx, ecx
    int 0x80
    pop_dcba
    ret

print_char:
    push_abcd
    mov [testenv_buffer], al
    mov eax, 4
    mov ebx, 1
    mov ecx, testenv_buffer
    mov edx, 1
    int 0x80
    pop_dcba
    ret
