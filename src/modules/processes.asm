;;;
;;; processes.asm
;;;
;;; Linux process handling (assembly part).
;;;


;; Constants from linux sources (include/linux/wait.h)
;;
%define WNOHANG         0x00000001

;;
;; app_fork (continuation passing procedure)
;;
;; Interface to linux fork() system call.
;;
;;   (fork APPLICATIVE [NEW-CONT]) => number
;;
;; In the child process:
;;
;;   Calls (APPLICATIVE) in the dynamic environment and the
;;   current continuation. If the continuation NEW-CONT is
;;   specifed, then the call is made in the dynamic extent
;;   of NEW-CONT. The implicit change of the dynamic extent
;;   does not invoke continuation guards.
;;
;; In the parent process:
;;
;;   Returns child process ID.
;;
;; TODO: reset performance statistics, if enabled (?)
;;
;; preconditions:  EBX = APPLICATIVE
;;                 EDI = current environment
;;                 EBP = current continuation
;;
app_fork:
  .A1:
    mov ecx, ebp
  .A2:
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, applicative_header(0)
    jne .type_error
    push ebx                 ; save the applicative
    mov ebx, ecx
    test bl, 3
    jnz .type_error
    mov eax, [ebx]
    cmp al, cont_header(0)
    jne .type_error
    push ebx                 ; save the continuation
    mov eax, 0x02            ; fork() linux system call
    call call_linux
    test eax, eax
    jz .child
    js .system_error
  .parent:
    lea esp, [esp + 8]       ; drop saved arguments
    lea eax, [4*eax + 1]     ; tag pid as fixint
    jmp [ebp + cont.program]
  .child:
    pop ebp                  ; EBP := new continuation
    pop eax                  ; EAX := APPLICATIVE
    mov ebx, nil_tag         ; EBX := ()
    jmp rn_combine
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_fork)
    jmp rn_error
  .system_error:
    mov ebx, eax             ; EBX := negated errno
    neg ebx                  ; EBX := errno
    lea ebx, [4*ebx + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_fork)
    jmp rn_error

;;
;; app_getpid (continuation passing procedure)
;;
;; Interface to linux getpid() system call.
;;
app_getpid:
  .A0:
    mov eax, 0x14            ; getpid()
    call call_linux
    test eax, eax
    js .system_error
    lea eax, [4*eax + 1]     ; tag pid as fixint
    jmp [ebp + cont.program]
  .system_error:
    neg eax                  ; EAX := negated errno
    lea ebx, [4*eax + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_getpid)
    jmp rn_error

;;
;; app_execve (continuation passing procedure)
;;
;; Interface to linux execve() system call.
;;
;;   (execve PROGRAM [ARGS [ENV]])
;;
;; where PROGRAM is a string
;;       ARGS    is a list of strings (default: (list PROGRAM))
;;       ENV     is a list of strings "NAME=VALUE" or #inert
;;
;; preconditions:  EBX = PROGRAM
;;                 ECX = ARGS
;;                 EDX = ENV
;;                 EBP = current continuation
;;
;; postcondition:  raise error or never return
;;
app_execve:
  .type_error:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_execve)
    jmp rn_error
  .A1:
    push ebx
    push dword nil_tag
    call rn_cons
    mov ecx, eax
  .A2:
    mov edx, keyword_value(rom_string_inherit)
  .A3:
    push ebx                 ; [EDI + 8] = PROGRAM
    push ecx                 ; [EDI + 4] = ARG list
    push edx                 ; [EDI + 0] = ENV list
    mov edi, esp
    cmp bl, string_tag
    jne .type_error
    ;; add terminator to program path
    call rn_blob_to_blobz
    mov [edi + 8], eax       ; [EDI + 8] = program stringz
    mov ebx, [edi + 4]
    ;; add terminator to arguments
    push dword unbound_tag
    call aux_build_argv
    mov [edi + 4], eax
    mov ebx, [edi]
    cmp ebx, keyword_value(rom_string_inherit)
    je .inherit_env
    ;; add terminator to environment equations
    call aux_build_argv
  .envp_built:
    mov [edi], eax
    ;; replace blob values with raw pointers
    mov esi, esp
  .fix_pointers:
    mov ebx, [esi]
    cmp ebx, unbound_tag
    je .fix_done
    cmp bl, bytevector_tag
    jne .skip
    call rn_get_blob_data
    mov [esi], ebx
  .skip:
    lea esi, [esi + 4]
    jmp .fix_pointers
  .fix_done:
    mov eax, 0x0B            ; execve
    mov ebx, [edi + 8]
    call rn_get_blob_data
    mov ecx, [edi + 4]
    mov edx, [edi]
    call call_linux
    neg eax
    lea ebx, [4*eax + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_execve)
    jmp rn_error
  .inherit_env:
    mov eax, [platform_info + linux.envp]
    jmp .envp_built

;;
;; aux_build_argv (irregular procedure)
;;
;; Build argument vector for execve() on the stack.
;;
;; preconditions:  EBX = list of strings
;;
;; postconditions: EAX = pointer to the array
;;                 ESP updated
;;
;; preserves:      EDI, EBP
;; clobbers:       EAX, EBX, ECX, EDX, ESP, EFLAGS
;;
aux_build_argv:
    push ebx                    ; save list head
    call rn_list_metrics
    pop ebx                     ; restore list head
    test eax, eax               ; improper list?
    jz app_execve.type_error
    test ecx, ecx               ; cyclic list?
    jnz app_execve.type_error
    mov ecx, edx                ; ECX = list length
    pop esi                     ; ESI := return address
    neg ecx
    lea edx, [esp + 4*ecx - 4]  ; reserve space
    neg ecx
    mov esp, edx                ;   on the stack
    push esi                    ; save return address
    mov esi, ebx                ; ESI := list
    jecxz .done
  .next:
    mov ebx, car(esi)
    cmp bl, string_tag          ; string?
    jne app_execve.type_error
    call rn_blob_to_blobz       ; convert to zero-terminated string
    mov esi, cdr(esi)           ; move to next input element
    mov [edx], eax              ; store output element
    lea edx, [edx + 4]          ; move to next output element
    loop .next
  .done:
    mov [edx], dword 0          ; array teminator
    lea eax, [esp + 4]          ; array address
    ret

;;
;; app_waitpid (continuation passing procedure)
;;
;; Interface to linux waitpid() system call.
;;
;;   (waitpid [PID] [#:nohang]) => (REAL-PID TYPE CODE)
;;
;; where PID is a number or #ignore
;;       REAL-PID is a number or #inert
;;       TYPE    is one of #:exited, #:waiting
;;       CODE    is a number or #inert
;;
;; preconditions:  EBX = PID
;;                 ECX = #nohang
;;                 EBP = current continuation
;;
app_waitpid:
  .A0:
    mov ebx, ignore_tag
  .A1:
    mov ecx, nil_tag
  .A2:
    call .compute_pid
    call .compute_options
    push dword 0
    mov eax, 0x07               ; waitpid() system call
    mov ecx, esp
    call call_linux
    test eax, eax
    jz .waiting
    js .system_error
  .got_pid:
    ;; return (PID TYPE CODE)
    pop ecx                  ; ECX := status
    test cl, cl
    jz .exited
  .signalled:
    ;; return (PID #:signalled SIGNO)
    lea ebx, [4*eax + 1]
    xor edx, edx
    mov dl, cl
    lea edx, [4*edx + 1]
    mov ecx, keyword_value(rom_string_signalled)
    jmp .return
  .exited:
    ;; return (PID #:exited CODE)
    lea ebx, [4*eax + 1]
    xor edx, edx
    mov dl, ch
    lea edx, [4*edx + 1]
    mov ecx, keyword_value(rom_string_exited)
    jmp .return
  .waiting:
    ;; return (#inert #:waiting #inert)
    lea esp, [esp + 4]
    mov ebx, inert_tag
    mov ecx, keyword_value(rom_string_waiting)
    mov edx, ebx
    jmp .return
  .return:
    ;; return list (EBX ECX EDX)
    push edx
    push dword nil_tag
    call rn_cons
    push ecx
    push eax
    call rn_cons
    push ebx
    push eax
    call rn_cons
    jmp [ebp + cont.program]

  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_waitpid)
    jmp rn_error
  .system_error:
    neg eax                  ; EAX := negated errno
    lea ebx, [4*eax + 1]     ; EBX := errno tagged as fixint
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_waitpid)
    jmp rn_error

  .compute_pid:
    cmp bl, ignore_tag
    je .pid_any_child
    mov eax, ebx
    xor al, 1
    test al, 3
    jnz .invalid_argument
    sar ebx, 2
    ret
  .pid_any_child:
    mov ebx, -1
    ret

  .compute_options:
    cmp ecx, nil_tag
    je .options_none
    cmp ecx, keyword_value(rom_string_nohang)
    je .options_nohang
    mov ebx, ecx
    jmp .invalid_argument
  .options_none:
    xor edx, edx
    ret
  .options_nohang:
    mov edx, WNOHANG
    ret

;;
;; app_open_raw_pipe (continuation passing procedure)
;;
;; Interface to linux pipe() system call.
;;
;;   (open-raw-pipe [#:no-cloexec]) => (RD-PORT WR-PORT)
;;
;; preconditions:  EBX = #:no-cloexec (optional)
;;                 EBP = current continuation
;;
app_open_raw_pipe:
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, symbol_value(rom_string_open_raw_pipe)
    jmp rn_error
  .system_error:
    neg eax
    lea ebx, [4*eax + 1]
    mov eax, err_syscall
    mov ecx, symbol_value(rom_string_open_raw_pipe)
    jmp rn_error
  .A1:
    cmp ebx, keyword_value(rom_string_no_cloexec)
    jne .invalid_argument
    xor ecx, ecx
    jmp .system_call
  .A0:
    mov ecx, O_CLOEXEC
  .system_call:
    mov eax, 0x14B        ; pipe2() linux system call
    lea esp, [esp - 8]
    mov ebx, esp
    call call_linux
    jnz .system_error
    pop edx               ; EDX := pipefd[0] = read file desc.
    pop esi               ; ESI := pipefd[1] = write file desc.
    lea edx, [4*edx + 1]  ; EDX := tagged read file descriptor
    lea esi, [4*esi + 1]  ; ESI := tagged read file descriptor
                          ; words  object
    mov ecx, 2*6 + 4      ;  2     #1=(#3# . #2#)
    call rn_allocate      ;  2     #2=(#2# . NIL)
    mov edi, eax          ;  6     #3=<port for reading>
                          ;  6     #4=<port for writing>
    lea eax, [edi + 16]
    mov [eax + bin_in.header], dword bin_in_header(6)
    mov [eax + bin_in.env], edx
    mov [eax + bin_in.close], dword primitive_value(linux_close)
    mov [eax + bin_in.read], dword primitive_value(linux_read)
    mov [eax + bin_in.peek], dword primitive_value(linux_nop)
    mov [eax + bin_in.var0], edx ; dummy
    mov [edi], eax
    lea eax, [eax + 6*4]
    mov [eax + bin_out.header], dword bin_out_header(6)
    mov [eax + bin_out.env], esi
    mov [eax + bin_out.close], dword primitive_value(linux_close)
    mov [eax + bin_out.write], dword primitive_value(linux_write)
    mov [eax + bin_out.flush], dword primitive_value(linux_nop)
    mov [eax + bin_out.var0], esi ; dummy
    mov [edi + 8], eax
    lea eax, [edi + 8]             ; tag #2#
    load_mutable_pair eax, eax     ;   as a mutable pair
    mov [edi + 4], eax             ;   store in #1#'s cdr
    mov [edi + 12], dword nil_tag  ; terminate the list
    load_mutable_pair eax, edi     ; tag #1# as a mutable pair
    xor edi, edi
    jmp [ebp + cont.program]
