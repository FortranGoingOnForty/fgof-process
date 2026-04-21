program test_parent_state
  use fgof_process, only : FGOF_PROCESS_OK, command, process_options, process_result, run, shell
  implicit none

  type(process_options) :: opts
  type(process_result) :: res
  character(len=:), allocatable :: before_pwd
  character(len=:), allocatable :: after_pwd
  character(len=:), allocatable :: home_before
  character(len=:), allocatable :: home_after
  character(len=:), allocatable :: guard_before
  character(len=:), allocatable :: guard_after
  logical :: has_home_before
  logical :: has_home_after
  logical :: has_guard_before
  logical :: has_guard_after

  opts%capture_stdout = .true.
  res = run(command("pwd"), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "capturing parent cwd should succeed"
  before_pwd = trim(res%stdout)

  opts = process_options()
  opts%cwd = "/"
  res = run(shell("test ""$PWD"" = ""/"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "child cwd override should not be a library error"
  if (res%exit_code /= 0) error stop "child cwd override should only affect the child"

  opts = process_options()
  opts%capture_stdout = .true.
  res = run(command("pwd"), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "capturing parent cwd after override should succeed"
  after_pwd = trim(res%stdout)
  if (after_pwd /= before_pwd) error stop "parent cwd should remain unchanged after child cwd override"

  call read_env("HOME", home_before, has_home_before)
  if (.not. has_home_before) error stop "HOME should exist in the parent environment"

  opts = process_options()
  opts%env_unset = ["HOME"]
  res = run(shell("test -z ""$HOME"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "child env_unset should not be a library error"
  if (res%exit_code /= 0) error stop "child env_unset should only affect the child"

  call read_env("HOME", home_after, has_home_after)
  if (.not. has_home_after) error stop "parent HOME should remain set after child env_unset"
  if (home_after /= home_before) error stop "parent HOME should remain unchanged after child env_unset"

  call read_env("FGOF_PROCESS_PARENT_GUARD", guard_before, has_guard_before)

  opts = process_options()
  opts%env_set = ["FGOF_PROCESS_PARENT_GUARD=child-only"]
  res = run(shell("test ""$FGOF_PROCESS_PARENT_GUARD"" = ""child-only"""), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop "child env_set should not be a library error"
  if (res%exit_code /= 0) error stop "child env_set should only affect the child"

  call read_env("FGOF_PROCESS_PARENT_GUARD", guard_after, has_guard_after)
  if (has_guard_after .neqv. has_guard_before) error stop "parent env_set state should remain unchanged"
  if (has_guard_after) then
    if (guard_after /= guard_before) error stop "parent env_set value should remain unchanged"
  end if

contains

  subroutine read_env(name, value, exists)
    character(len=*), intent(in) :: name
    character(len=:), allocatable, intent(out) :: value
    logical, intent(out) :: exists
    integer :: env_length
    integer :: env_status
    character(len=:), allocatable :: buffer

    call get_environment_variable(name, length=env_length, status=env_status)
    if (env_status /= 0) then
      exists = .false.
      value = ""
      return
    end if

    allocate(character(len=env_length) :: buffer)
    call get_environment_variable(name, value=buffer, status=env_status)
    if (env_status /= 0) then
      exists = .false.
      value = ""
      return
    end if

    exists = .true.
    value = buffer
  end subroutine read_env

end program test_parent_state
