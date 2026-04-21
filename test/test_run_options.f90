program test_run_options
  use fgof_process, only : FGOF_PROCESS_OK, process_options, process_result, run, shell
  implicit none

  type(process_options) :: opts
  type(process_result) :: res
  character(len=:), allocatable :: cwd_check

  opts%cwd = "/"
  cwd_check = 'test "$(pwd)" = "/"'
  res = run(shell(cwd_check), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "cwd override should not be a library error"
  if (res%exit_code /= 0) error stop "cwd override should succeed"

  opts = process_options()
  opts%env_set = ["FGOF_PROCESS_TEST=hello"]
  res = run(shell("test ""$FGOF_PROCESS_TEST"" = ""hello"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "env_set should not be a library error"
  if (res%exit_code /= 0) error stop "env_set should affect the child"

  opts = process_options()
  opts%env_set = ["FGOF_PROCESS_TEST=hello "]
  res = run(shell("test ""$FGOF_PROCESS_TEST"" = ""hello """), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "env_set trailing spaces should not be a library error"
  if (res%exit_code /= 0) error stop "env_set should preserve trailing spaces"

  opts = process_options()
  opts%env_set = ["FGOF_PROCESS_TEST=hello"]
  opts%env_unset = ["FGOF_PROCESS_TEST"]
  res = run(shell("test -z ""$FGOF_PROCESS_TEST"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "env_unset should not be a library error"
  if (res%exit_code /= 0) error stop "env_unset should clear the child variable"
end program test_run_options
