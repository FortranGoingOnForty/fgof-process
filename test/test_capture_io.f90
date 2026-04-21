program test_capture_io
  use fgof_process, only : FGOF_PROCESS_OK, process_options, process_result, run, shell
  implicit none

  type(process_options) :: opts
  type(process_result) :: res

  opts%capture_stdout = .true.
  res = run(shell("printf 'hello'"), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "stdout capture should not be a library error"
  if (res%stdout /= "hello") error stop "stdout capture mismatch"

  opts = process_options()
  opts%capture_stderr = .true.
  res = run(shell("printf 'oops' >&2"), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "stderr capture should not be a library error"
  if (res%stderr /= "oops") error stop "stderr capture mismatch"

  opts = process_options()
  opts%stdin = "hello" // new_line("a")
  res = run(shell("read value; test ""$value"" = ""hello"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "stdin piping should not be a library error"
  if (res%exit_code /= 0) error stop "stdin piping should affect the child"
end program test_capture_io
