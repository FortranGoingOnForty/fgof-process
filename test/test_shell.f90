program test_shell
  use fgof_process, only : FGOF_PROCESS_MODE_SHELL, process_command, shell
  implicit none

  type(process_command) :: cmd

  cmd = shell("printf 'hello from shell'")

  if (cmd%mode /= FGOF_PROCESS_MODE_SHELL) error stop "mode mismatch"
  if (.not. allocated(cmd%command_line)) error stop "command_line not allocated"
  if (cmd%command_line /= "printf 'hello from shell'") error stop "command_line mismatch"
  if (.not. allocated(cmd%argv)) error stop "argv not allocated"
  if (size(cmd%argv) /= 0) error stop "shell argv should be empty"
end program test_shell
