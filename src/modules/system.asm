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

pred_file_exists:
    ;; see predicates.asm for calling conventions
    cmp bl, string_tag
    jne .type_error
    call rn_blob_to_blobz
    mov ebx, eax
    call rn_get_blob_data
    mov ecx, scratchpad_start
    mov eax, 0xC3         ; linux stat64() system call
    call call_linux
    mov ebx, eax
    xor eax, eax
    test ebx, ebx
    setz al
    ret
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, [esi + operative.var0]
    jmp rn_error

app_delete_file:
  .A1:
    cmp bl, string_tag
    jne .type_error
    call rn_blob_to_blobz
    mov ebx, eax
    call rn_get_blob_data
    mov eax, 0x0A         ; linux unlink() system call
    call call_linux
    test eax, eax
    jnz .system_error
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_delete_file)
    jmp rn_error
  .system_error:
    neg eax                  ; EAX := negated errno
    lea ebx, [4*eax + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_delete_file)
    jmp rn_error

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

app_collect_garbage:
  .A0:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor esi, esi
    xor edi, edi
    push ebp
    call gc_collect
    pop ebp
    call bl_collect
    mov eax, inert_tag
    jmp [ebp + cont.program]

%if (configured_performance_statistics == 1)
app_perf_time:
  .A1:
    mov eax, ebx
    xor al, 1
    test al, 3
    jnz .error
    cmp ebx, fixint_value(0)
    jl .error
    cmp ebx, fixint_value(perf_time_section_count)
    jge .error
    shr ebx, 2
    mov eax, [perf_time_buffer + 8*ebx]
    mov edx, [perf_time_buffer + 8*ebx + 4]
    xor ebx, ebx
    call rn_u64_to_bigint
    jmp [ebp + cont.program]
  .error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_perf_time)
    jmp rn_error
%endif
