;;;
;;; performance-statistics.asm
;;;

;;
;; perf_time {begin|end}, SECTION-NAME [, save_regs]
;;
;; Mark beginning and end of section with execution time
;; measurement.
;;
;; preserves: ECX, EBX, ESI, EDI, EBP
;; clobbers: EAX, EDX, EFLAGS
;;
%macro perf_time 2-3
%ifidn %3, save_regs
    pushf
    push eax
    push edx
%endif
    rdtsc
%ifidn %1, begin
    sub [perf_time_buffer + perf_time_section_%2 * 8], eax
    sbb [perf_time_buffer + perf_time_section_%2 * 8 + 4], edx
%elifidn %1, end
    add [perf_time_buffer + perf_time_section_%2 * 8], eax
    adc [perf_time_buffer + perf_time_section_%2 * 8 + 4], edx
%else
    %error "invalid use of perf_time macro"
%endif
%ifidn %3, save_regs
    pop edx
    pop eax
    popf
%else
    xor eax, eax
    xor edx, edx
%endif
%endmacro
