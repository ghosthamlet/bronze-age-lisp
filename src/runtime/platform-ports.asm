;;;
;;; platform-ports.asm
;;;
;;; Linux file descriptors wrapped as port objects.
;;;

EINTR     equ 4

O_RDONLY  equ 0o0000000  ; octal, see linux headers
O_WRONLY  equ 0o0000001
O_CREAT   equ 0o0000100
O_NOCTTY  equ 0o0000400
O_TRUNC   equ 0o0001000
O_CLOEXEC equ 0o2000000

    align 4
linux_close:
    ;; pre:  ebx = #inert
    ;;       edi = file descriptor (tagged fixint)
    ;;       ebp = continuation
    ;; post: eax = #inert
    ;; linux syscal list at http://syscalls.kernelgrok.com/
    mov eax, 6    ; "close" system call number
    mov ebx, edi
    shr ebx, 2
    call call_linux
    test eax, eax
    jnz .fail
    mov al, inert_tag
    jmp [ebp + cont.program]
  .fail:
    mov ebx, eax
    neg ebx
    shl ebx, 2
    or bl, fixint_tag
    mov eax, err_io
    mov ecx, inert_tag
    jmp rn_error

;;
;; linux_read (continuation passing procedure)
;;
;; preconditions:  EBX = request length (tagged fixint, positive)
;;                 EDI = file descriptor (tagged fixint)
;;                 EBP = continuation
;;
;; postconditions: EAX = bytevector or eof-object
;;
    align 4
linux_read:
    push ebx
    mov ecx, ebx
    shr ecx, 2
    call rn_allocate_blob
    push eax
    mov ebx, eax
    call rn_get_blob_data
    mov edx, ecx    ; buffer length
    mov ecx, ebx    ; buffer address
    mov ebx, edi    ; tagged file descriptor
    shr ebx, 2      ; untag
    mov eax, 3      ; "read" system call number
    call call_linux ;
    test eax, eax   ; check return code
    jz .eof
    js .error
    mov ecx, eax
    pop ebx
    call rn_shrink_last_blob
    mov eax, ebx
    pop ecx
    jmp [ebp + cont.program]
  .eof:
    add esp, 8
    mov eax, eof_tag
    jmp [ebp + cont.program]
  .error:
    pop edx
    cmp eax, -EINTR
    je .eintr
    mov ebx, eax
    neg ebx
    shl ebx, 2
    or bl, fixint_tag
    mov eax, err_io
    mov ecx, inert_tag
    jmp rn_error
  .eintr:
    mov eax, primitive_value(linux_read)
    pop ebx
    jmp rn_combine.reflect

    align 4
linux_write:
    ;; pre:  ebx = buffer (bytevector)
    ;;       edi = file descriptor (tagged fixint)
    ;;       ebp = continuation
    ;; post: eax = #inert
    cmp bl, bytevector_tag
    jne .invalid_argument
    mov esi, ebx
    call rn_get_blob_data
    mov edx, ecx    ; buffer length
    mov ecx, ebx    ; buffer address
    mov ebx, edi    ; tagged file descriptor
    shr ebx, 2      ; untag
    mov eax, 4      ; "write" system call number
    call call_linux ;
    test eax, eax   ; check return code
    js .error
    lea eax, [fixint_tag + 4*eax] ; tag
    jmp [ebp + cont.program]
  .error:
    cmp eax, -EINTR
    je .eintr
    mov ebx, eax
    neg ebx
    shl ebx, 2
    or bl, fixint_tag
    mov eax, err_io
    mov ecx, inert_tag
    jmp rn_error
  .eintr:
    mov eax, primitive_value(linux_write)
    mov ebx, esi
    jmp rn_combine.reflect
  .invalid_argument:
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error

    align 4
linux_nop:
    mov eax, dword inert_tag
    jmp [ebp + cont.program]

linux_open_input:
    ;; ebx = name (string)
    call rn_blob_to_blobz
    mov ebx, eax
    call rn_get_blob_data
    mov eax, 5 ; open syscall
    mov ecx, O_RDONLY | O_CLOEXEC
    mov edx, 0
    call call_linux
    test eax, eax   ; check return code
    js .error
    lea eax, [fixint_tag + 4*eax] ; tag
    ret
  .error:
    mov ebx, eax
    neg ebx
    lea ebx, [4*ebx + fixint_tag]
    mov eax, err_io
    mov ecx, inert_tag
    jmp rn_error

linux_open_output:
    ;; ebx = name (string)
    call rn_blob_to_blobz
    mov ebx, eax
    call rn_get_blob_data
    mov eax, 5 ; open syscall
    mov ecx, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC
    mov edx, 0o666
    call call_linux
    test eax, eax   ; check return code
    js .error
    lea eax, [fixint_tag + 4*eax] ; tag
    ret
  .error:
    mov ebx, eax
    neg ebx
    lea ebx, [4*ebx + fixint_tag]
    mov eax, err_io
    mov ecx, inert_tag
    jmp rn_error

copy_blobz:
    ;; pre: ebx = blob
    ;; post: eax = new blob
    push ecx
    push ebx
    call rn_get_blob_data
    inc ecx
    call rn_allocate_blob
    dec ecx
    xchg ebx, eax
    call rn_copy_blob_data
    mov eax, ebx
    call rn_get_blob_data
    mov [ebx + ecx - 1], byte 0
    pop ebx
    pop ecx
    ret

%define POLLIN  0x0001

;;
;; preconditions:  EBX = file descriptor (tagged fixint)
;; postconditions: EAX = #t or #f
;;
rn_file_descriptor_ready:
    push ebx
    push ecx
    push edx
    ;; create struct pollfd on the stack
    shr ebx, 2
    push dword POLLIN
    push ebx
    ;; call poll()
    mov eax, 0xA8  ; poll() syscall
    mov ebx, esp   ;  pointer to struct pollfd
    mov ecx, 1     ;  number of structures
    mov edx, 0     ;  timeout
    call call_linux
    add esp, 8
    mov ebx, boolean_value(0)
    test eax, eax
    js .error
    setnz bh
    mov eax, ebx
    pop edx
    pop ecx
    pop ebx
    ret
  .error:
    mov eax, err_io
    lea ebx, [4 * eax + 1]
    mov ecx, inert_tag
    jmp rn_error

;;
;; rn_dup2 (native procedure)
;;
;; File descriptor duplication.
;;
;; preconditions:  EBX = file descriptor (tagged fixint)
;;                 ECX = file descriptor (tagged fixint)
;;                 ESI = symbol for error reporting
;;
rn_dup2:
    mov eax, 0x3F   ; linux dup2() system call
    shr ebx, 2
    shr ecx, 2
    call call_linux
    test eax, eax
    js .system_error
    ret
  .system_error:
    neg eax
    lea ebx, [4*eax + 1]
    mov eax, err_syscall
    mov ecx, esi
    jmp rn_error

%define TCGETS  0x5401
%define TCSETSF 0x5404
%define NCCS    19

struc termios
  .c_iflag resd 1
  .c_oflag resd 1
  .c_cflag resd 1
  .c_lflag resd 1
  .c_line  resb 1
  .c_cc    resb NCCS
endstruc

%define ISIG    0o0000001
%define ICANON  0o0000002
%define ECHO    0o0000010

%define ICRNL   0o0000400
%define IUTF8   0o0040000

%define VTIME   5
%define VMIN    6

;;
;; rn_isatty
;;
;; Terminal detection.
;;
;; preconditions:  EBX = file descriptor (tagged fixint)
;; postconditions: EAX = #t or #f
;;
rn_isatty:
    push ebx
    push ecx
    push edx
    mov eax, 0x36             ; ioctl syscall
    shr ebx, 2                ;   fd (untag)
    mov ecx, TCGETS           ;   cmd = TCGETS
    mov edx, scratchpad_start ;   buffer for termios structure
    call call_linux
    mov ebx, boolean_value(0)
    test eax, eax
    setz bh
    mov eax, ebx
    pop edx
    pop ecx
    pop ebx
    ret

;;
;; rn_tcgets (native procedure)
;;
;; Copy current terminal settings to a bytevector.
;;
;; preconditions:  EBX = file descriptor (tagged fixint)
;; postconditions: EAX = bytevector
;;
;; clobbers:  EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
;; preserves: EBP
;;
rn_tcgets:
    mov esi, ebx
    mov ecx, termios_size
    call rn_allocate_blob
    mov edi, eax
    mov ebx, eax
    call rn_get_blob_data
    mov edx, ebx              ;   buffer for termios structure
    mov ecx, TCGETS           ;   cmd = TCGETS
    mov ebx, esi              ;   fd
    shr ebx, 2                ;    (untag)
    mov eax, 0x36             ; ioctl syscall
    call call_linux
    test eax, eax
    jnz .error
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    mov eax, edi
    ret
  .error:
    mov eax, err_io
    mov ebx, esi
    mov ecx, inert_tag
    jmp rn_error

;;
;; rn_tcsets (native procedure)
;;
;; Copy current terminal settings from a bytevector.
;;
;; preconditions:  EBX = file descriptor (tagged fixint)
;;                 ECX = bytevector
;;
;; postconditions: EAX = #inert
;;
;; clobbers:  EAX, EBX, ECX, EDX, ESI, EDI, EFLAGS
;; preserves: EBP
;;
rn_tcsets:
    mov esi, ebx
    mov ebx, ecx
    call rn_get_blob_data
    cmp ecx, termios_size
    jne .error
    mov edx, ebx              ;   termios structure
    mov ecx, TCSETSF          ;   cmd = TCSETSF
    mov ebx, esi              ;   fd
    shr ebx, 2                ;    (untag)
    mov eax, 0x36             ; ioctl syscall
    call call_linux
    test eax, eax
    jnz .error
    mov eax, inert_tag
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    ret
  .error:
    mov eax, err_io
    mov ebx, esi
    mov ecx, inert_tag
    jmp rn_error

;;
;; rn_tc_cbreak_noecho (native procedure)
;;
;; Update the termios structure:
;;
;;    - disable echo
;;    - enable noncanonical char-by-char processing
;;    - enable signal on Ctrl-C
;;
;; preconditions:  EBX = bytevector with termios structure
;; postconditions: EAX = #inert
;;
;; clobbers:  EAX, EBX, ECX, EDX, EFLAGS
;; preserves: ESI, EDI, EBP
;;
rn_tc_cbreak_noecho:
    mov eax, ebx
    call rn_get_blob_data
    cmp ecx, termios_size
    jne .error
    ;; modify termios structure
    and dword [ebx + termios.c_iflag], ~ICRNL
    mov eax, [ebx + termios.c_lflag]
    and eax, ~ICANON & ~ECHO
    or  eax, ISIG
    mov [ebx + termios.c_lflag], eax
    mov byte [ebx + termios.c_cc + VMIN], 1
    mov byte [ebx + termios.c_cc + VTIME], 0
    ;; discard native pointer and return #inert
    xor ebx, ebx
    mov eax, inert_tag
    ret
  .error:
    mov ebx, eax
    mov eax, err_invalid_argument
    mov ecx, inert_tag
    jmp rn_error
