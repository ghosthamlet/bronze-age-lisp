;;;
;;; platform-signals.asm
;;;
;;; Signal handling.
;;;

%define SA_ONSTACK 0x08000000

;;
;; rn_sigring_read (native procedure)
;;
;; postconditions: EAX = next signal number, if the ring buffer is not empty
;;                     = eof-object          if the ring buffer is empty
;;                     = #ignore             if the ring buffer overflew
;;                 signal number removed from the ring buffer
;;
;; clobbers:       EAX, EFLAGS
;; preserves:      EBX, ECX, EDX, ESI, EDI, EBP
;; stack usage:    2 dwords (incl. call/ret)
;;
rn_sigring_read:
    push ebx
    mov eax, [sigring_wp]
    mov ebx, [sigring_rp]
    cmp eax, ebx
    je .empty
  .nonempty:
    mov eax, [sigring_buffer + ebx * sigring_element_size + sigring_element.signo]
    inc ebx
    and ebx, (2 * configured_signal_ring_capacity - 1)
    mov [sigring_rp], ebx
    lea eax, [4 * eax + 1]  ; tag as fixint
    pop ebx
    ret
  .empty:
    pop ebx
    mov eax, [sigring_overflow]
    test eax, eax
    jnz .overflow
    mov eax, eof_tag
    ret
  .overflow:
    mov eax, ignore_tag
    ret

;;
;; rn_sigring_write (native procedure)
;;
;; preconditions:  EBX = signal number (untagged)
;;
;; postconditions: new element added to the ring buffer
;;                 or [sigring_overflow] = 1
;;
;; clobbers:       EFLAGS
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP
;; stack usage:    2 dwords (incl. call/ret)
;;
rn_sigring_write:
    push eax
    push edx
    mov edx, [sigring_wp]
    mov eax, [sigring_rp]
    xor eax, edx
    test eax, configured_signal_ring_capacity
    jnz .full
  .space:
    mov [sigring_buffer + edx * sigring_element_size + sigring_element.signo], ebx
    inc edx
    and edx, (2 * configured_signal_ring_capacity - 1)
    mov [sigring_wp], edx
    pop edx
    pop eax
    ret
  .full:
    mov dword [sigring_overflow], 1
    pop edx
    pop eax
    ret

;;
;; si_signal_handler (C-callable procedure)
;;
;; Signal handler.
;;
si_signal_handler:
    push ebp              ; SystemV 386 ABI
    mov ebp, esp          ;  function prologue
    push ebx              ;
    mov ebx, [ebp + 8]    ; fetch 1st argument
    call rn_sigring_write ; store it in the ring buffer
    call rn_interrupt_evaluator
    pop ebx
    leave                 ; function
    ret                   ;  epilogue

;;
;; rn_signal_init (native procedure)
;;
;; Initialize for signal handling.
;;
;; clobbers: EAX
;;
rn_signal_init:
    mov eax, [sigring_initialized]
    test eax, eax
    jz .init
    ret
  .init:
    pusha
    mov [sigring_initialized], dword 1
    ;; create stack_t structure
    push dword (signal_stack_limit - signal_stack_base) ; ss_size
    push dword 0                                        ; ss_flags
    push dword signal_stack_base                        ; ss_sp
    mov eax, 0xBA    ; sigaltstack(stack_t *ss, stack_t *oldss)
    mov ebx, esp     ; ss
    mov ecx, 0       ; oldss = NULL
    call call_linux
    test eax, eax
    jnz .system_error
    add esp, 12
    popa
    ret
  .system_error:
    lea ebx, [4 * eax + 1]
    mov eax, err_signal_initialization
    mov ecx, inert_tag
    jmp rn_error

;;
;; rn_signal_setup (native procedure)
;;
;; Enable signal handling.
;;
;; preconditions: EBX = signal number (tagged integer)
;;                ECX = #t for enabling signal handler,
;;                      #f to use default action
;;                      #ignore to ignore the signal
;;
;; preserves: ESI, EDI, EBP
;;
rn_signal_setup:
    ;; prepare signal stack
    call rn_signal_init
    ;;
    cmp ecx, boolean_value(1)
    je .enable
    cmp ecx, ignore_tag
    je .ignore
  .default:
    mov eax, 0                   ; SIG_DFL
    jmp .create_struct_sigaction
  .ignore:
    mov eax, 1                   ; SIG_IGN
    jmp .create_struct_sigaction
  .enable:
    mov eax, si_signal_handler
  .create_struct_sigaction:
    push esi
    ;; create struct sigaction on the stack
    push dword 0xFFFFFFFF        ; sa_mask
    push dword 0xFFFFFFFF        ;
    push dword 0                 ; sa_restorer (unused)
    push dword SA_ONSTACK        ; sa_flags
    push eax                     ; sa_handler
    mov eax, 0xAE                ; rt_sigaction() syscall
    shr ebx, 2                   ;   signo (untag)
    mov ecx, esp                 ;   act
    mov edx, 0                   ;   old
    mov esi, 8                   ;   sizeof(sigset_t)
    call call_linux
    test eax, eax
    jnz .system_error
    add esp, 20
    pop esi
    ret
  .system_error:
    lea ebx, [4 * eax + 1]
    mov eax, err_signal_initialization
    mov ecx, inert_tag
    jmp rn_error
