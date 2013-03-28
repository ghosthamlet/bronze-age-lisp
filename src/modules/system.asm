
app_get_interpreter_arguments:
  .A0:
    call rn_interpreter_arguments
    jmp [ebp + cont.program]
