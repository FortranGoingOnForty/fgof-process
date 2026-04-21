program test_mode_boundaries
  use fgof_process, only : FGOF_PROCESS_OK, command, process_options, process_result, run, shell
  implicit none

  type(process_options) :: opts
  type(process_result) :: res

  opts%capture_stdout = .true.

  res = run(command("printf", [character(len=26) :: "%s", "left | sed 's/left/right/'"]), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "argv literal capture should not be a library error"
  if (res%stdout /= "left | sed 's/left/right/'") error stop "argv mode should not interpret shell pipelines"

  res = run(command("printf", [character(len=5) :: "%s", "$HOME"]), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "argv env literal capture should not be a library error"
  if (res%stdout /= "$HOME") error stop "argv mode should not expand shell variables"

  res = run(command("printf", [character(len=2) :: "%s", "a "]), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "argv trailing space capture should not be a library error"
  if (res%stdout /= "a ") error stop "argv mode should preserve trailing spaces"

  res = run(shell("printf 'left' | sed 's/left/right/'"), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "shell pipeline should not be a library error"
  if (res%stdout /= "right") error stop "shell mode should interpret shell pipelines"
end program test_mode_boundaries
