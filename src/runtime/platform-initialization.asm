struc linux
  .vsyscall resd 1
  .argc resd 1
  .argv resd 1
  .envp resd 1
  .auxv resd 1
endstruc

call_linux:
    perf_time begin, system_call, save_regs
    push esi
    push edi
    call [platform_info + linux.vsyscall]
    pop edi
    pop esi
    perf_time end, system_call, save_regs
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    ret

AT_SYSINFO equ 32

rn_platform_init:
    ;; Find the start of the Initial Process Stack, as defined
    ;; by System V ABI for i386 systems.
    lea ebp, [esp + 4]
    ;; Save command line argument count and pointer to the
    ;; vector of command line arguments.
    mov ecx, [ebp]     ; command line argument count
    rn_trace configured_debug_evaluator, 'argc', hex, ecx
    mov [platform_info + linux.argc], ecx
    lea eax, [ebp + 4]
    mov [platform_info + linux.argv], eax
    ;; Skip argument vector and save pointer to the
    ;; vector of environment variables.
    lea ebx, [ebp + 8 + 4*ecx]
    mov [platform_info + linux.envp], ebx
    ;; Skip vector of environment variables.
  .skip_envp:
    mov eax, [ebx]
    lea ebx, [ebx + 4]
    test eax, eax
    jnz .skip_envp
    ;; Save pointer to the ELF auxilliary vector.
    mov [platform_info + linux.auxv], ebx
    ;; Find the AT_SYSINFO element, which contains
    ;; the address of
  .skip_aux:
    mov eax, [ebx]
    cmp eax, AT_SYSINFO
    jz .found
    lea ebx, [ebx + 8]
    jmp .skip_aux
  .found:
    mov eax, [ebx + 4]
    rn_trace configured_debug_evaluator, 'vsyscall', hex, eax
    mov [platform_info + linux.vsyscall], eax
    ret

rn_lisp_init:
    call init_lisp_heap
    call init_blob_heap
    mov ecx, 4
    call rn_allocate
    mov ebp, eax
    mov [ebp + cont.header], dword cont_header(6)
    mov [ebp + cont.parent], dword root_continuation
    pop dword [ebp + cont.program]
    mov [ebp + cont.var0], dword inert_tag
    mov edi, private_env_object
    mov eax, inert_tag
    mov ebx, init_form
    mov ecx, inert_tag
    jmp rn_eval

rn_interpreter_arguments:
    push ebx
    push ecx
    push edx
    push esi
    mov ecx, [platform_info + linux.argc]
    mov esi, [platform_info + linux.argv]
    mov edx, nil_tag
    jecxz .done
  .next:
    push ecx
    mov ebx, [esi + 4 * ecx - 4]
    call rn_stringz_to_blob
    mov al, string_tag
    push eax
    push edx
    call rn_cons
    mov edx, eax
    pop ecx
    loop .next
  .done:
    mov eax, edx
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;;
;; rn_list_environment_variables (native procedure)
;;
;; preconditions:  EDI = list tail
;;                 EBP = current continuation (for error reporting)
;;
;; postconditions: All environment variables are added
;;                 to the environment.
;;
;; preserves:      ESI, EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, EFLAGS
;;
rn_list_environment_variables:
    push esi
    mov edx, [platform_info + linux.envp]
    mov ebx, [edx]
    test ebx, ebx
    jz .done
  .next_variable:
    call .split
    mov al, string_tag
    mov bl, string_tag
    push eax
    push ebx
    call rn_cons
    push eax
    push edi
    call rn_cons
    mov edi, eax
    lea edx, [edx + 4]
    mov ebx, [edx]
    test ebx, ebx
    jne .next_variable
  .done:
    pop esi
    ret
  .split:
    mov esi, ebx
  .split.scan_eq:
    mov al, [esi]
    test al, al
    je .split.noeq
    cmp al, '='
    je .split.eq
    inc esi
    jmp .split.scan_eq
  .split.eq:
    mov ecx, esi
    sub ecx, ebx
    call rn_allocate_blob
    xchg ebx, eax
    call rn_copy_blob_data
    push ebx
    lea ebx, [esi + 1]
  .split.scan_z:
    inc esi
    mov al, [esi]
    test al, al
    jne .split.scan_z
    mov ecx, esi
    sub ecx, ebx
    call rn_allocate_blob
    xchg ebx, eax
    call rn_copy_blob_data
    pop eax
    ret
  .split.noeq:
    mov ecx, esi
    sub ecx, ebx
    call rn_allocate_blob
    xchg ebx, eax
    call rn_copy_blob_data
    mov eax, ebx
    mov ebx, rom_empty_string
    ret

global _start
_start:
    mov [stack_limit], esp
    call rn_platform_init
    call rn_lisp_init
    mov ebx, ground_env_object
    call rn_make_list_environment ; standard environment
    mov edi, eax
    mov eax, inert_tag
    mov ebx, start_form
    mov ecx, inert_tag
    mov edx, rn_exit
    mov ebp, root_continuation
    jmp rn_eval

cont_root:
    ;; eax = argument
    rn_trace configured_debug_evaluator, 'cont_root', hex, eax, lisp, eax
    cmp eax, boolean_value(1)
    je .success
    cmp al, inert_tag
    je .success
    mov ebx, eax
    xor  al, 1
    test al, 3
    je .fixint
    mov ebx, 1
    jmp .exit
  .fixint:
    sar ebx, 2
    jmp .exit
  .success:
    mov ebx, 0
  .exit:
    mov eax, 1
    jmp call_linux

cont_error:
    mov ebx, eax
    mov eax, inert_tag
    mov ecx, inert_tag
    jmp rn_fatal
