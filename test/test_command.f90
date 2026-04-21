program test_command
  use fgof_process, only : process_command, command
  implicit none

  type(process_command) :: cmd

  cmd = command("printf", ["hello", "world"])

  if (.not. allocated(cmd%program)) error stop "program not allocated"
  if (cmd%program /= "printf") error stop "program mismatch"
  if (.not. allocated(cmd%argv)) error stop "argv not allocated"
  if (size(cmd%argv) /= 2) error stop "argv size mismatch"
  if (cmd%argv(1) /= "hello") error stop "argv(1) mismatch"
  if (cmd%argv(2) /= "world") error stop "argv(2) mismatch"
end program test_command
