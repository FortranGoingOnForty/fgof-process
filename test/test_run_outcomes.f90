program test_run_outcomes
  use fgof_process, only : FGOF_PROCESS_ERR_EXEC_FAILED, FGOF_PROCESS_OK, command, process_result, run, shell
  implicit none

  type(process_result) :: res

  res = run(shell("exit 7"))
  if (res%error_code /= FGOF_PROCESS_OK) error stop "shell exit should not be a library error"
  if (.not. res%launched) error stop "shell command should launch"
  if (.not. res%completed) error stop "shell command should complete"
  if (.not. res%exited_normally) error stop "shell exit should be normal"
  if (res%exit_code /= 7) error stop "shell exit code mismatch"

  res = run(command("fgof-process-command-that-does-not-exist"))
  if (res%error_code /= FGOF_PROCESS_ERR_EXEC_FAILED) error stop "missing command should be exec failure"
end program test_run_outcomes
