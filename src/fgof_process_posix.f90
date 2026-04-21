module fgof_process_posix
  use iso_c_binding, only : c_char, c_int, c_null_char
  use fgof_process_types, only : &
    FGOF_PROCESS_ERR_EXEC_FAILED, &
    FGOF_PROCESS_ERR_INTERNAL, &
    FGOF_PROCESS_ERR_PIPE_FAILED, &
    FGOF_PROCESS_ERR_SPAWN_FAILED, &
    FGOF_PROCESS_ERR_TIMEOUT, &
    FGOF_PROCESS_MODE_ARGV, &
    FGOF_PROCESS_MODE_SHELL, &
    FGOF_PROCESS_OK, &
    process_command, &
    process_options, &
    process_result
  implicit none
  private

  public :: run_posix_basic

  integer(c_int), parameter :: POSIX_RUN_OK = 0
  integer(c_int), parameter :: POSIX_RUN_ERR_PIPE = 1
  integer(c_int), parameter :: POSIX_RUN_ERR_FCNTL = 2
  integer(c_int), parameter :: POSIX_RUN_ERR_FORK = 3
  integer(c_int), parameter :: POSIX_RUN_ERR_WAIT = 4
  integer(c_int), parameter :: PATH_BUFFER_LEN = 1024

  interface
    function fgof_process_run_basic(program, argv_blob, argc, arg_stride, command_line, use_shell, cwd, &
                                    stdin_data, use_stdin, capture_stdout, capture_stderr, timeout_ms, &
                                    env_set_blob, env_set_count, env_set_stride, &
                                    env_unset_blob, env_unset_count, env_unset_stride, &
                                    stdout_path, stdout_path_len, stderr_path, stderr_path_len, &
                                    exit_code, term_signal, exec_failed, timed_out, sys_errno) bind(C, name="fgof_process_run_basic")
      import :: c_char, c_int
      character(kind=c_char), intent(in) :: program(*)
      character(kind=c_char), intent(in) :: argv_blob(*)
      integer(c_int), value :: argc
      integer(c_int), value :: arg_stride
      character(kind=c_char), intent(in) :: command_line(*)
      integer(c_int), value :: use_shell
      character(kind=c_char), intent(in) :: cwd(*)
      character(kind=c_char), intent(in) :: stdin_data(*)
      integer(c_int), value :: use_stdin
      integer(c_int), value :: capture_stdout
      integer(c_int), value :: capture_stderr
      integer(c_int), value :: timeout_ms
      character(kind=c_char), intent(in) :: env_set_blob(*)
      integer(c_int), value :: env_set_count
      integer(c_int), value :: env_set_stride
      character(kind=c_char), intent(in) :: env_unset_blob(*)
      integer(c_int), value :: env_unset_count
      integer(c_int), value :: env_unset_stride
      character(kind=c_char), intent(out) :: stdout_path(*)
      integer(c_int), value :: stdout_path_len
      character(kind=c_char), intent(out) :: stderr_path(*)
      integer(c_int), value :: stderr_path_len
      integer(c_int), intent(out) :: exit_code
      integer(c_int), intent(out) :: term_signal
      integer(c_int), intent(out) :: exec_failed
      integer(c_int), intent(out) :: timed_out
      integer(c_int), intent(out) :: sys_errno
      integer(c_int) :: fgof_process_run_basic
    end function fgof_process_run_basic
  end interface

contains

  subroutine run_posix_basic(cmd, options, res)
    type(process_command), intent(in) :: cmd
    type(process_options), intent(in), optional :: options
    type(process_result), intent(inout) :: res

    character(kind=c_char), allocatable :: c_program(:)
    character(kind=c_char), allocatable :: c_argv_blob(:)
    character(kind=c_char), allocatable :: c_command_line(:)
    character(kind=c_char), allocatable :: c_cwd(:)
    character(kind=c_char), allocatable :: c_stdin_data(:)
    character(kind=c_char), allocatable :: c_env_set_blob(:)
    character(kind=c_char), allocatable :: c_env_unset_blob(:)
    character(kind=c_char), allocatable :: c_stdout_path(:)
    character(kind=c_char), allocatable :: c_stderr_path(:)
    integer(c_int) :: argc
    integer(c_int) :: arg_stride
    integer(c_int) :: use_shell
    integer(c_int) :: use_stdin
    integer(c_int) :: capture_stdout
    integer(c_int) :: capture_stderr
    integer(c_int) :: timeout_ms
    integer(c_int) :: env_set_count
    integer(c_int) :: env_set_stride
    integer(c_int) :: env_unset_count
    integer(c_int) :: env_unset_stride
    integer(c_int) :: exit_code
    integer(c_int) :: term_signal
    integer(c_int) :: exec_failed
    integer(c_int) :: timed_out
    integer(c_int) :: sys_errno
    integer(c_int) :: rc
    integer :: start_count
    integer :: finish_count
    integer :: rate

    call system_clock(start_count, rate)

    select case (cmd%mode)
    case (FGOF_PROCESS_MODE_ARGV)
      use_shell = 0_c_int
      c_program = to_c_string(cmd%program)
      call pack_string_array(cmd%argv, arg_stride, c_argv_blob)
      argc = int(size(cmd%argv), c_int)
      c_command_line = empty_c_string()
    case (FGOF_PROCESS_MODE_SHELL)
      use_shell = 1_c_int
      c_program = empty_c_string()
      c_argv_blob = empty_c_string()
      argc = 0_c_int
      arg_stride = 0_c_int
      c_command_line = to_c_string(cmd%command_line)
    case default
      call set_error(res, FGOF_PROCESS_ERR_INTERNAL, "unsupported command mode")
      return
    end select

    if (present(options)) then
      if (allocated(options%cwd)) then
        c_cwd = to_c_string(options%cwd)
      else
        c_cwd = empty_c_string()
      end if

      if (allocated(options%stdin)) then
        c_stdin_data = to_c_string(options%stdin)
        use_stdin = 1_c_int
      else
        c_stdin_data = empty_c_string()
        use_stdin = 0_c_int
      end if

      if (options%capture_stdout) then
        capture_stdout = 1_c_int
      else
        capture_stdout = 0_c_int
      end if

      if (options%capture_stderr) then
        capture_stderr = 1_c_int
      else
        capture_stderr = 0_c_int
      end if

      timeout_ms = int(options%timeout_ms, c_int)

      if (allocated(options%env_set)) then
        call pack_string_array(options%env_set, env_set_stride, c_env_set_blob)
        env_set_count = int(size(options%env_set), c_int)
      else
        c_env_set_blob = empty_c_string()
        env_set_count = 0_c_int
        env_set_stride = 0_c_int
      end if

      if (allocated(options%env_unset)) then
        call pack_string_array(options%env_unset, env_unset_stride, c_env_unset_blob)
        env_unset_count = int(size(options%env_unset), c_int)
      else
        c_env_unset_blob = empty_c_string()
        env_unset_count = 0_c_int
        env_unset_stride = 0_c_int
      end if
    else
      c_cwd = empty_c_string()
      c_stdin_data = empty_c_string()
      use_stdin = 0_c_int
      capture_stdout = 0_c_int
      capture_stderr = 0_c_int
      timeout_ms = 0_c_int
      c_env_set_blob = empty_c_string()
      c_env_unset_blob = empty_c_string()
      env_set_count = 0_c_int
      env_set_stride = 0_c_int
      env_unset_count = 0_c_int
      env_unset_stride = 0_c_int
    end if

    allocate(c_stdout_path(PATH_BUFFER_LEN))
    allocate(c_stderr_path(PATH_BUFFER_LEN))
    c_stdout_path = c_null_char
    c_stderr_path = c_null_char

    rc = fgof_process_run_basic(c_program, c_argv_blob, argc, arg_stride, c_command_line, use_shell, c_cwd, &
                                c_stdin_data, use_stdin, capture_stdout, capture_stderr, timeout_ms, &
                                c_env_set_blob, env_set_count, env_set_stride, &
                                c_env_unset_blob, env_unset_count, env_unset_stride, &
                                c_stdout_path, int(size(c_stdout_path), c_int), &
                                c_stderr_path, int(size(c_stderr_path), c_int), &
                                exit_code, term_signal, exec_failed, timed_out, sys_errno)

    call system_clock(finish_count)
    if (rate > 0) then
      res%elapsed_ms = int((real(finish_count - start_count) / real(rate)) * 1000.0)
    else
      res%elapsed_ms = 0
    end if

    if (capture_stdout /= 0_c_int) then
      res%stdout = read_and_delete_text_file(from_c_string(c_stdout_path))
    end if

    if (capture_stderr /= 0_c_int) then
      res%stderr = read_and_delete_text_file(from_c_string(c_stderr_path))
    end if

    select case (rc)
    case (POSIX_RUN_OK)
      if (exec_failed /= 0_c_int) then
        call set_error(res, FGOF_PROCESS_ERR_EXEC_FAILED, errno_message("exec failed", sys_errno))
        return
      end if

      res%launched = .true.
      res%completed = .true.
      res%timed_out = (timed_out /= 0_c_int)
      res%term_signal = int(term_signal)

      if (res%timed_out) then
        call set_error(res, FGOF_PROCESS_ERR_TIMEOUT, "process timed out")
        res%exited_normally = .false.
        res%exit_code = -1
        return
      end if

      res%error_code = FGOF_PROCESS_OK
      res%error_message = ""

      if (term_signal > 0_c_int) then
        res%exited_normally = .false.
        res%exit_code = -1
      else
        res%exited_normally = .true.
        res%exit_code = int(exit_code)
      end if

    case (POSIX_RUN_ERR_PIPE, POSIX_RUN_ERR_FCNTL)
      call set_error(res, FGOF_PROCESS_ERR_PIPE_FAILED, errno_message("pipe setup failed", sys_errno))
    case (POSIX_RUN_ERR_FORK)
      call set_error(res, FGOF_PROCESS_ERR_SPAWN_FAILED, errno_message("fork failed", sys_errno))
    case default
      call set_error(res, FGOF_PROCESS_ERR_INTERNAL, errno_message("process wait failed", sys_errno))
    end select
  end subroutine run_posix_basic

  subroutine set_error(res, code, message)
    type(process_result), intent(inout) :: res
    integer, intent(in) :: code
    character(len=*), intent(in) :: message

    res%error_code = code
    res%error_message = trim(message)
  end subroutine set_error

  function to_c_string(str) result(buf)
    character(len=*), intent(in) :: str
    character(kind=c_char), allocatable :: buf(:)
    integer :: i
    integer :: n

    n = len_trim(str)
    allocate(buf(n + 1))
    do i = 1, n
      buf(i) = str(i:i)
    end do
    buf(n + 1) = c_null_char
  end function to_c_string

  function empty_c_string() result(buf)
    character(kind=c_char), allocatable :: buf(:)

    allocate(buf(1))
    buf(1) = c_null_char
  end function empty_c_string

  subroutine pack_string_array(values, stride, buffer)
    character(len=*), intent(in) :: values(:)
    integer(c_int), intent(out) :: stride
    character(kind=c_char), allocatable, intent(out) :: buffer(:)
    integer :: i
    integer :: j
    integer :: width
    integer :: offset

    if (size(values) == 0) then
      stride = 0_c_int
      buffer = empty_c_string()
      return
    end if

    width = max_trimmed_length(values) + 1
    stride = int(width, c_int)
    allocate(buffer(size(values) * width))
    buffer = c_null_char

    do i = 1, size(values)
      offset = (i - 1) * width
      do j = 1, len_trim(values(i))
        buffer(offset + j) = values(i)(j:j)
      end do
      buffer(offset + len_trim(values(i)) + 1) = c_null_char
    end do
  end subroutine pack_string_array

  integer function max_trimmed_length(values) result(max_len)
    character(len=*), intent(in) :: values(:)
    integer :: i

    max_len = 1
    do i = 1, size(values)
      max_len = max(max_len, len_trim(values(i)))
    end do
  end function max_trimmed_length

  function errno_message(prefix, errnum) result(message)
    character(len=*), intent(in) :: prefix
    integer(c_int), intent(in) :: errnum
    character(len=:), allocatable :: message
    character(len=32) :: code_text

    write(code_text, '(I0)') int(errnum)
    message = trim(prefix) // " (errno=" // trim(code_text) // ")"
  end function errno_message

  function from_c_string(buf) result(text)
    character(kind=c_char), intent(in) :: buf(:)
    character(len=:), allocatable :: text
    integer :: i
    integer :: n

    n = 0
    do i = 1, size(buf)
      if (buf(i) == c_null_char) exit
      n = n + 1
    end do

    if (n == 0) then
      text = ""
      return
    end if

    allocate(character(len=n) :: text)
    do i = 1, n
      text(i:i) = char(iachar(buf(i)))
    end do
  end function from_c_string

  function read_and_delete_text_file(path) result(text)
    character(len=*), intent(in) :: path
    character(len=:), allocatable :: text
    integer :: unit
    integer :: ios
    integer :: file_size

    if (len_trim(path) == 0) then
      text = ""
      return
    end if

    open(newunit=unit, file=trim(path), status="old", access="stream", form="unformatted", action="read", iostat=ios)
    if (ios /= 0) then
      text = ""
      return
    end if

    inquire(unit=unit, size=file_size)
    if (file_size <= 0) then
      text = ""
      close(unit, status="delete")
      return
    end if

    allocate(character(len=file_size) :: text)
    read(unit, iostat=ios) text
    if (ios /= 0) text = ""
    close(unit, status="delete")
  end function read_and_delete_text_file

end module fgof_process_posix
