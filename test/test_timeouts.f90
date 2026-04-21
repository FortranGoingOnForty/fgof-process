program test_timeouts
  use fgof_process, only : FGOF_PROCESS_ERR_TIMEOUT, process_options, process_result, run, shell
  implicit none

  type(process_options) :: opts
  type(process_result) :: res

  opts%capture_stdout = .true.
  opts%timeout_ms = 100
  res = run(shell("printf 'begin'; sleep 2"), opts)

  if (res%error_code /= FGOF_PROCESS_ERR_TIMEOUT) error stop "timeout should be a library timeout error"
  if (.not. res%timed_out) error stop "timed_out should be true"
  if (res%stdout /= "begin") error stop "partial stdout should be preserved on timeout"
end program test_timeouts
