program test_validation
  use fgof_process, only : &
    FGOF_PROCESS_ERR_INVALID_COMMAND, &
    FGOF_PROCESS_ERR_INVALID_OPTION, &
    FGOF_PROCESS_MODE_ARGV, &
    process_command, &
    process_options, &
    process_result, &
    run, &
    shell
  implicit none

  type(process_command) :: argv_cmd
  type(process_command) :: shell_cmd
  type(process_options) :: opts
  type(process_result) :: res

  argv_cmd%mode = FGOF_PROCESS_MODE_ARGV
  argv_cmd%program = ""
  allocate(character(len=1) :: argv_cmd%argv(0))

  res = run(argv_cmd)
  if (res%error_code /= FGOF_PROCESS_ERR_INVALID_COMMAND) error stop "empty argv command should be invalid"

  shell_cmd = shell("")
  res = run(shell_cmd)
  if (res%error_code /= FGOF_PROCESS_ERR_INVALID_COMMAND) error stop "empty shell command should be invalid"

  shell_cmd = shell("printf 'ok'")
  opts%timeout_ms = -1
  res = run(shell_cmd, opts)
  if (res%error_code /= FGOF_PROCESS_ERR_INVALID_OPTION) error stop "negative timeout should be invalid"
end program test_validation
