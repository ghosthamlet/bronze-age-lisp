;;;
;;; platform-ports.asm
;;;
;;; Linux file descriptors wrapped as port objects.
;;;

EINTR    equ 4

O_RDONLY equ 0o0000000  ; octal, see linux headers
O_WRONLY equ 0o0000001
O_CREAT  equ 0o0000100
O_NOCTTY equ 0o0000400
O_TRUNC  equ 0o0001000

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

    align 4
linux_read:
    ;; pre:  ebx = request length (tagged fixint, positive)
    ;;       edi = file descriptor (tagged fixint)
    ;;       ebp = continuation
    ;; post: eax = number of bytes read (tagged fixint) or eof-object
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
    mov ecx, O_RDONLY
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
    mov ecx, O_WRONLY | O_CREAT | O_TRUNC
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
    mov ecx, 0x5401           ;   cmd = TCGETS
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
