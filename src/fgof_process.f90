module fgof_process
  use fgof_process_posix, only : run_posix_basic
  use fgof_process_types, only : &
    FGOF_PROCESS_ERR_EXEC_FAILED, &
    FGOF_PROCESS_ERR_INVALID_COMMAND, &
    FGOF_PROCESS_ERR_INVALID_OPTION, &
    FGOF_PROCESS_ERR_NOT_IMPLEMENTED, &
    FGOF_PROCESS_ERR_PIPE_FAILED, &
    FGOF_PROCESS_ERR_SPAWN_FAILED, &
    FGOF_PROCESS_MODE_ARGV, &
    FGOF_PROCESS_MODE_NONE, &
    FGOF_PROCESS_MODE_SHELL, &
    FGOF_PROCESS_OK, &
    process_command, &
    process_options, &
    process_result
  implicit none
  private

  public :: process_command
  public :: process_options
  public :: process_result
  public :: FGOF_PROCESS_MODE_NONE
  public :: FGOF_PROCESS_MODE_ARGV
  public :: FGOF_PROCESS_MODE_SHELL
  public :: FGOF_PROCESS_OK
  public :: FGOF_PROCESS_ERR_INVALID_COMMAND
  public :: FGOF_PROCESS_ERR_INVALID_OPTION
  public :: FGOF_PROCESS_ERR_SPAWN_FAILED
  public :: FGOF_PROCESS_ERR_EXEC_FAILED
  public :: FGOF_PROCESS_ERR_PIPE_FAILED
  public :: FGOF_PROCESS_ERR_NOT_IMPLEMENTED
  public :: command
  public :: shell
  public :: run

contains

  function command(program, argv) result(cmd)
    character(len=*), intent(in) :: program
    character(len=*), intent(in), optional :: argv(:)
    type(process_command) :: cmd
    integer :: arg_len
    integer :: i

    cmd%mode = FGOF_PROCESS_MODE_ARGV
    cmd%program = trim(program)

    if (present(argv)) then
      arg_len = max_trimmed_length(argv)
      allocate(character(len=arg_len) :: cmd%argv(size(argv)))
      do i = 1, size(argv)
        cmd%argv(i) = trim(argv(i))
      end do
    else
      allocate(character(len=1) :: cmd%argv(0))
    end if
  end function command

  function shell(command_line) result(cmd)
    character(len=*), intent(in) :: command_line
    type(process_command) :: cmd

    cmd%mode = FGOF_PROCESS_MODE_SHELL
    cmd%command_line = trim(command_line)
    allocate(character(len=1) :: cmd%argv(0))
  end function shell

  function run(cmd, options) result(res)
    type(process_command), intent(in) :: cmd
    type(process_options), intent(in), optional :: options
    type(process_result) :: res
    integer :: i

    call init_result(res)

    select case (cmd%mode)
    case (FGOF_PROCESS_MODE_ARGV)
      if (.not. allocated(cmd%program)) then
        call set_error(res, FGOF_PROCESS_ERR_INVALID_COMMAND, "argv command program is not set")
        return
      end if

      if (len_trim(cmd%program) == 0) then
        call set_error(res, FGOF_PROCESS_ERR_INVALID_COMMAND, "argv command program must not be empty")
        return
      end if

    case (FGOF_PROCESS_MODE_SHELL)
      if (.not. allocated(cmd%command_line)) then
        call set_error(res, FGOF_PROCESS_ERR_INVALID_COMMAND, "shell command line is not set")
        return
      end if

      if (len_trim(cmd%command_line) == 0) then
        call set_error(res, FGOF_PROCESS_ERR_INVALID_COMMAND, "shell command line must not be empty")
        return
      end if

    case default
      call set_error(res, FGOF_PROCESS_ERR_INVALID_COMMAND, "command mode is not set")
      return
    end select

    if (present(options)) then
      if (options%timeout_ms < 0) then
        call set_error(res, FGOF_PROCESS_ERR_INVALID_OPTION, "timeout_ms must be >= 0")
        return
      end if

      if (options%timeout_ms > 0) then
        call set_error(res, FGOF_PROCESS_ERR_NOT_IMPLEMENTED, "timeout support is not implemented yet")
        return
      end if

      if (options%capture_stdout) then
        call set_error(res, FGOF_PROCESS_ERR_NOT_IMPLEMENTED, "stdout capture is not implemented yet")
        return
      end if

      if (options%capture_stderr) then
        call set_error(res, FGOF_PROCESS_ERR_NOT_IMPLEMENTED, "stderr capture is not implemented yet")
        return
      end if

      if (allocated(options%stdin)) then
        call set_error(res, FGOF_PROCESS_ERR_NOT_IMPLEMENTED, "stdin piping is not implemented yet")
        return
      end if

      if (allocated(options%env_set)) then
        do i = 1, size(options%env_set)
          if (len_trim(options%env_set(i)) == 0) then
            call set_error(res, FGOF_PROCESS_ERR_INVALID_OPTION, "env_set entries must not be empty")
            return
          end if

          if (index(options%env_set(i), "=") <= 1) then
            call set_error(res, FGOF_PROCESS_ERR_INVALID_OPTION, "env_set entries must use KEY=VALUE format")
            return
          end if
        end do
      end if

      if (allocated(options%env_unset)) then
        do i = 1, size(options%env_unset)
          if (len_trim(options%env_unset(i)) == 0) then
            call set_error(res, FGOF_PROCESS_ERR_INVALID_OPTION, "env_unset entries must not be empty")
            return
          end if
        end do
      end if
    end if

    call run_posix_basic(cmd, options, res)
  end function run

  subroutine init_result(res)
    type(process_result), intent(out) :: res

    res%launched = .false.
    res%completed = .false.
    res%timed_out = .false.
    res%exited_normally = .false.
    res%exit_code = -1
    res%term_signal = 0
    res%stdout = ""
    res%stderr = ""
    res%error_code = FGOF_PROCESS_OK
    res%error_message = ""
    res%elapsed_ms = 0
  end subroutine init_result

  subroutine set_error(res, code, message)
    type(process_result), intent(inout) :: res
    integer, intent(in) :: code
    character(len=*), intent(in) :: message

    res%error_code = code
    res%error_message = trim(message)
  end subroutine set_error

  integer function max_trimmed_length(values) result(max_len)
    character(len=*), intent(in) :: values(:)
    integer :: i

    max_len = 1
    do i = 1, size(values)
      max_len = max(max_len, len_trim(values(i)))
    end do
  end function max_trimmed_length

end module fgof_process
