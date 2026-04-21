module fgof_process_types
  implicit none
  private

  public :: FGOF_PROCESS_MODE_NONE
  public :: FGOF_PROCESS_MODE_ARGV
  public :: FGOF_PROCESS_MODE_SHELL
  public :: FGOF_PROCESS_OK
  public :: FGOF_PROCESS_ERR_INVALID_COMMAND
  public :: FGOF_PROCESS_ERR_INVALID_OPTION
  public :: FGOF_PROCESS_ERR_SPAWN_FAILED
  public :: FGOF_PROCESS_ERR_EXEC_FAILED
  public :: FGOF_PROCESS_ERR_PIPE_FAILED
  public :: FGOF_PROCESS_ERR_TIMEOUT
  public :: FGOF_PROCESS_ERR_INTERNAL
  public :: FGOF_PROCESS_ERR_NOT_IMPLEMENTED
  public :: process_command
  public :: process_options
  public :: process_result

  integer, parameter :: FGOF_PROCESS_MODE_NONE = 0
  integer, parameter :: FGOF_PROCESS_MODE_ARGV = 1
  integer, parameter :: FGOF_PROCESS_MODE_SHELL = 2

  integer, parameter :: FGOF_PROCESS_OK = 0
  integer, parameter :: FGOF_PROCESS_ERR_INVALID_COMMAND = 10
  integer, parameter :: FGOF_PROCESS_ERR_INVALID_OPTION = 11
  integer, parameter :: FGOF_PROCESS_ERR_SPAWN_FAILED = 20
  integer, parameter :: FGOF_PROCESS_ERR_EXEC_FAILED = 21
  integer, parameter :: FGOF_PROCESS_ERR_PIPE_FAILED = 22
  integer, parameter :: FGOF_PROCESS_ERR_TIMEOUT = 23
  integer, parameter :: FGOF_PROCESS_ERR_INTERNAL = 99
  integer, parameter :: FGOF_PROCESS_ERR_NOT_IMPLEMENTED = 1000

  type :: process_command
    integer :: mode = FGOF_PROCESS_MODE_NONE
    character(len=:), allocatable :: program
    character(len=:), allocatable :: argv(:)
    character(len=:), allocatable :: command_line
  end type process_command

  type :: process_options
    character(len=:), allocatable :: cwd
    character(len=:), allocatable :: stdin
    logical :: capture_stdout = .false.
    logical :: capture_stderr = .false.
    integer :: timeout_ms = 0
    character(len=:), allocatable :: env_set(:)
    character(len=:), allocatable :: env_unset(:)
  end type process_options

  type :: process_result
    logical :: launched = .false.
    logical :: completed = .false.
    logical :: timed_out = .false.
    logical :: exited_normally = .false.
    integer :: exit_code = -1
    integer :: term_signal = 0
    character(len=:), allocatable :: stdout
    character(len=:), allocatable :: stderr
    integer :: error_code = FGOF_PROCESS_OK
    character(len=:), allocatable :: error_message
    integer :: elapsed_ms = 0
  end type process_result

end module fgof_process_types
