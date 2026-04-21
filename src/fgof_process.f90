module fgof_process
  implicit none
  private

  public :: process_command
  public :: process_options
  public :: process_result
  public :: command
  public :: run

  type :: process_command
    character(len=:), allocatable :: program
    character(len=:), allocatable :: argv(:)
  end type process_command

  type :: process_options
    character(len=:), allocatable :: cwd
    logical :: capture_stdout = .false.
    logical :: capture_stderr = .false.
    integer :: timeout_ms = 0
    character(len=:), allocatable :: env(:)
  end type process_options

  type :: process_result
    integer :: exit_code = -1
    logical :: timed_out = .false.
    character(len=:), allocatable :: stdout
    character(len=:), allocatable :: stderr
    character(len=:), allocatable :: error_message
  end type process_result

contains

  function command(program, argv) result(cmd)
    character(len=*), intent(in) :: program
    character(len=*), intent(in), optional :: argv(:)
    type(process_command) :: cmd
    integer :: i

    cmd%program = trim(program)

    if (present(argv)) then
      allocate(character(len=len_trim(program)) :: cmd%argv(0))
      deallocate(cmd%argv)
      allocate(character(len=max(1, max_trimmed_length(argv))) :: cmd%argv(size(argv)))
      do i = 1, size(argv)
        cmd%argv(i) = trim(argv(i))
      end do
    else
      allocate(character(len=1) :: cmd%argv(0))
    end if
  end function command

  function run(cmd, options) result(res)
    type(process_command), intent(in) :: cmd
    type(process_options), intent(in), optional :: options
    type(process_result) :: res

    res%exit_code = -1
    res%timed_out = .false.
    res%stdout = ""
    res%stderr = ""
    res%error_message = "run() is not implemented yet"

    if (.not. allocated(cmd%program)) then
      res%error_message = "command program is not set"
      return
    end if

    if (present(options)) then
      if (options%timeout_ms < 0) then
        res%error_message = "timeout_ms must be >= 0"
        return
      end if
    end if
  end function run

  integer function max_trimmed_length(values) result(max_len)
    character(len=*), intent(in) :: values(:)
    integer :: i

    max_len = 1
    do i = 1, size(values)
      max_len = max(max_len, len_trim(values(i)))
    end do
  end function max_trimmed_length

end module fgof_process
