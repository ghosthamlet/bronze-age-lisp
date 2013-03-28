;;;
;;; inerpreter-operatives.asm
;;;
;;; Execution of interpreted operatives.
;;;

%define vau.senv      operative.var0
%define vau.formals   operative.var1
%define vau.eformal   operative.var2
%define vau.body      operative.var3
%define vau.name      operative.var4
%define vau.reserved  operative.var5

;;
;; operate_interpreted (continuation passing procedure)
;;
;; Execute interpreted operative.
;;
;; preconditions:  EAX = closure
;;                   vau.senv = static environment
;;                   vau.formals = formal parameter tree
;;                   vau.eformal = dynamic env. formal parameter
;;                   vau.body = body of the procedure
;;                   vau.name = name of the procedure
;;                 EBX = parameter tree
;;                 EDI = dynamic environment
;;                 EBP = current continuation
;;
operate_interpreted:
  .env:
    ;; general variant for the case vau.eformal = symbol
    mov ecx, eax                       ; ecx := closure
    mov edx, ebx                       ; edx := arguments
    mov ebx, [ecx + vau.formals]       ; ebx := formals
    call rn_match_ptree_procz          ; check if args match
    jnz .error
    mov esi, edi                       ; esi := dynamic env.
    mov eax, edi                       ; eax := dynamic env.
    call rn_capture                    ; capture dynamic env.
    mov ebx, [ecx + vau.senv]          ; get static env.
    call rn_make_list_environment      ; allocate new child env.
    mov edi, eax                       ; set dynamic env.
    mov ebx, [ecx + vau.formals]       ; ebx := formals
    call rn_bind_ptree                 ; bind parameter tree
    mov ebx, [ecx + vau.eformal]       ; ebx := eformal
    mov edx, esi                       ; edx := dynamic env.
    call rn_bind_ptree                 ; bind environment
    mov ebx, [ecx + vau.body]          ; get user lisp code
    jmp rn_sequence                    ; evaluate in $sequence
  .error:
    mov eax, err_match_failure         ; error message
    mov ebx, edx                       ; arguments
    mov ecx, [ecx + vau.name]          ; procedure name
    jmp rn_error
  .noenv:
    ;; simple variant for the case vau.eformal = #ignore
    mov ecx, eax                       ; ecx := closure
    mov edx, ebx                       ; edx := arguments
    mov ebx, [ecx + vau.formals]       ; ebx := formals
    call rn_match_ptree_procz          ; check if args match
    jnz .error
    mov esi, ebx                       ; esi := formals
    mov ebx, [ecx + vau.senv]          ; get static environment
    call rn_make_list_environment      ; allocate new child env.
    mov edi, eax                       ; set dynamic environment
    mov ebx, esi                       ; ebx := formals
    call rn_bind_ptree                 ; bind parameter tree
    mov ebx, [ecx + vau.body]          ; get user lisp code
    jmp rn_sequence                    ; evaluate in $sequence

;;
;; rn_allocate_closure (native procedure)
;;
;; Build interpreted operative closure.
;;
;; preconditions:  EBX = formal parameter tree
;;                 ECX = environment formal parameter (symbol or #ignore)
;;                 EDX = procedure body
;;                 EDI = static environment
;;
;; postconditions: EAX = closure
;;
;; preserves:      EDI, EBP
;; clobbers:       EAX, EBX, ECX, ESI, EDI, EBP, EFLAGS
;;
rn_allocate_closure:
    cmp cl, symbol_tag
    je .env
  .noenv:
    mov esi, operate_interpreted.noenv
    jmp .alloc
  .env:
    mov esi, operate_interpreted.env
  .alloc:
    ;; ensure that the static environment is persistent
    mov eax, edi
    call rn_capture
    ;; allocate closure
    push ecx
    mov ecx, 8
    call rn_allocate
    pop ecx
    mov [eax + operative.header], dword operative_header(8)
    mov [eax + operative.program], esi
    mov [eax + vau.senv], edi
    mov [eax + vau.formals], ebx
    mov [eax + vau.eformal], ecx
    mov [eax + vau.body], edx
    mov [eax + vau.name], dword inert_tag
    mov [eax + vau.reserved], dword inert_tag
    ret

%define cont.helper.environment cont.var0
%define cont.helper.combination cont.var1
%define cont.helper.ptree       cont.var2

;;
;; make_helper_continuation (native procedure)
;;
;; Save EBX, EDI and EBP in a newly allocated continuation.
;;
make_helper_continuation:
    push eax
    push ecx
    mov ecx, -6
    call rn_allocate_transient
    mov [eax + cont.header], dword cont_header(6)
    mov [eax + cont.program], edx
    mov [eax + cont.parent], ebp
    mov [eax + cont.helper.environment], edi
    mov [eax + cont.helper.combination], ebx
    mov [eax + cont.helper.ptree], ebx
    mov ebp, eax
    pop ecx
    pop eax
    ret

;;
;; discard_helper_continuation (native procedure)
;;
;; Restore EBX, EDI and EBP from the continuation
;; created by make_helper_continuation.
;;
discard_helper_continuation:
    mov ebx, [ebp + cont.helper.ptree]
    mov edi, [ebp + cont.helper.environment]
    mov ebp, [ebp + cont.parent]
    ret

;;
;; rn_sequence (continuation passing procedure)
;;
;; Implementation of ($sequence ...)
;;
;; preconditions:  EBX = list of forms to be evaluated
;;                 EDI = dynamic environment
;;                 EBP = continuation
;;
rn_sequence:
primop_Ssequence:
    pair_nil_cases
    mov eax, err_invalid_argument_structure
    mov ecx, symbol_value(rom_string_Ssequence)
    jmp rn_error
  .case.nil:
    mov eax, inert_tag
    jmp [ebp + cont.program]
  .case.pair:
    mov eax, cdr(ebx)
    cmp eax, nil_tag
    je .tail
    mov eax, car(ebx)
    mov ebx, cdr(ebx)
    mov edx, .next
    call make_helper_continuation
    mov ebx, eax
    jmp rn_eval
  .next:
    call discard_helper_continuation
    jmp rn_sequence
  .tail:
    mov ebx, car(ebx)
    jmp rn_eval
