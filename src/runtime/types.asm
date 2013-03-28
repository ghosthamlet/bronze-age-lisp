;;;
;;; types.asm
;;;
;;; Declaration of lisp types.
;;;

fixint_tag equ 1
%define fixint_value(x) (((x) << 2) | 1)

;;
;; load_immutable_pair REGISTER, ADDRESS
;; load_mutable_pair REGISTER, ADDRESS
;;
;; car(REGISTER)
;; cdr(REGISTER)
;;
%macro load_immutable_pair 2
    mov %1, %2
    shr %1, 1
    or  %1, 0x00000003
%endmacro

%macro load_mutable_pair 2
    mov %1, %2
    shr %1, 1
    or  %1, 0x80000003
%endmacro

%define car(x)          [2*(x) - 6]
%define cdr(x)          [2*(x) - 2]

;;
;; rom_pair_value(LABEL)
;;
;; The pointers to pairs are tagged and the tagging scheme
;; is too complicated for relocations supported by ELF format,
;; and address calculations supported by NASM and GNU ld.
;;
;; To overcome this limitation, the read-only pair objects are
;; placed in a dedicated section '.lisp_rom', which starts at
;; absolute virtual address 0x09000000 (see the linker scripts).
;;
;; The macro absolute_rom_address(LABEL) reinterprets the address
;; of LABEL as a 'scalar', which can be used in arbitrary arithmetic
;; expression.
;;
%define absolute_rom_address(x) (((x) - lisp_rom_base) + 0x09000000)
%define rom_pair_value(x) ((absolute_rom_address(x) >> 1) | 0x00000003)

;;
;; pair_nil_cases (macro with no arguments)
;;
;; Type dispatch on pairs and nil.
;;
;; preconditions:  EBX = value
;; postconditions: EIP = .case.pair if value is a pair
;;                 EIP = .case.nil if value is ()
;;                 EIP = fallthrough otherwise
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP
;; clobbers:       EFLAGS
;;
;; example: mov ebx, VALUE
;;          pair_nil_cases
;;          OTHER_CODE
;;          .case.pair: PAIR_CODE
;;          .case.nil: NIL_CODE
;;
%macro pair_nil_cases 0
    test bl, 3
    jz .case.other
    jp .case.pair
    cmp bl, nil_tag
    je .case.nil
  .case.other:
%endmacro

;;
;; bool_cases (macro with no arguments)
;;
;; Dispatch on boolean value
;;
;; preconditions:  EBX = value
;; postconditions: EIP = .case.true if value is #t
;;                 EIP = .case.false if value is #f
;;                 EIP = fallthrough otherwise
;; preserves:      EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP
;; clobbers:       EFLAGS
;;
;; example: mov ebx, VALUE
;;          bool_cases
;;          OTHER_CODE
;;          .case.true: TRUE_CODE
;;          .case.false: FALSE_CODE
;;
%macro bool_cases 0
    cmp ebx, boolean_tag
    je .case.false
    cmp ebx, boolean_tag | 256
    je .case.true
  .case.other:
%endmacro


%macro jump_if_not_pair 2
    test %1, 3
    jz %2
    jnp %2
%endmacro