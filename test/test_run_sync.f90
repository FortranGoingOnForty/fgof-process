program test_run_sync
  use fgof_process, only : FGOF_PROCESS_OK, command, process_result, run
  implicit none

  type(process_result) :: res

  res = run(command("true"))

  if (res%error_code /= FGOF_PROCESS_OK) error stop "true should not be a library error"
  if (.not. res%launched) error stop "true should launch"
  if (.not. res%completed) error stop "true should complete"
  if (.not. res%exited_normally) error stop "true should exit normally"
  if (res%exit_code /= 0) error stop "true should exit zero"
end program test_run_sync
