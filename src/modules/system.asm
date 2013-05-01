;;;
;;; system.asm
;;;
;;; Features from the System module (compatible with klisp).
;;;

app_get_interpreter_arguments:
  .A0:
    call rn_interpreter_arguments
    jmp [ebp + cont.program]

app_rdtsc:
  .A0:
    rdtsc
    call rn_u64_to_bigint
    jmp [ebp + cont.program]

app_get_current_second:
  .A0:
    sub esp, 8         ; sizeof(struct timeval)
    mov eax, 0x4E      ; gettimeofday linux syscall
    mov ebx, esp       ; 1st arg = address of struct timeval
    xor ecx, ecx       ; 2nd arg = timezone = NULL
    call call_linux    ; (ignore error code)
    mov eax, [esp]     ; EAX := seconds treated as 32-bit unsigned integer
    xor edx, edx       ; EDX := 0
    add esp, 8
    call rn_u64_to_bigint
    jmp [ebp + cont.program]

app_get_current_jiffy:
  .A0:
    sub esp, 8         ; sizeof(struct timeval)
    mov eax, 0x4E      ; gettimeofday linux syscall
    mov ebx, esp       ; 1st arg = address of struct timeval
    xor ecx, ecx       ; 2nd arg = timezone = NULL
    call call_linux    ; (ignore error code)
    mov eax, [esp]     ; EAX := seconds treated as 32-bit unsigned integer
    mov ebx, 1000000   ; EBX := 10^6 = second/microsecond
    mul ebx            ; EDX:EAX := 10^6 * seconds
    add eax, [esp + 4]
    adc edx, 0         ; EDX:EAX := 10^6 * seconds + microseconds
    add esp, 8
    call rn_u64_to_bigint
    jmp [ebp + cont.program]

app_get_jiffies_per_second:
  .A0:
    mov eax, fixint_value(1000000)
    jmp [ebp + cont.program]

op_init_environ:
    mov edi, private_binding(rom_string_environ)
    cmp edi, inert_tag
    je .init
    jmp [ebp + cont.program]
  .init:
    mov edi, nil_tag
    call rn_list_environment_variables
    mov private_binding(rom_string_environ), edi
    jmp [ebp + cont.program]
