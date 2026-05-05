# fgof-process

[![CI](https://github.com/FortranGoingOnForty/fgof-process/actions/workflows/ci.yml/badge.svg)](https://github.com/FortranGoingOnForty/fgof-process/actions/workflows/ci.yml)

POSIX-first process and subprocess helpers for modern Fortran applications.

`fgof-process` is intended to be a small, standalone library that gives Fortran tools a more ergonomic process API than raw `execute_command_line`, thin POSIX wrappers, or experimental process surfaces that still feel too low-level for real tooling.

It is built for the kind of Fortran programs that need to orchestrate other tools: shells, editors, TUI apps, developer tooling, test fixtures, and automation helpers.

It is the first package in the [FortranGoingOnForty lib-modules](https://github.com/FortranGoingOnForty/lib-modules) catalog, but it is intended to stand on its own as a normal `fpm` package.

Current v1 target:

- argv-first command construction
- synchronous process execution on macOS and Linux
- explicit shell-command convenience through `/bin/sh -c`
- environment overrides
- working-directory overrides
- stdin support
- stdout and stderr capture
- exit-status reporting
- timeout-aware execution
- structured, result-first errors

Future scope:

- streaming process handles
- async spawn and wait
- signal helpers
- PTY-friendly integration points for a future `fgof-pty`
- a dedicated `fgof-proc-test` companion package

## Status

Sync-first `v0.1.1` is released.

The core synchronous path is implemented and tested. `v0.1.1` carries the
post-`v0.1.0` C interface binding wrap needed by downstream CI compilers.

Implemented today:

- public `fgof_process` and `fgof_process_types` modules
- `command()` and `shell()` constructors
- synchronous argv and shell execution
- child-only cwd override
- child-only env set and unset behavior
- stdin piping
- stdout capture
- stderr capture
- timeout enforcement with partial output preservation
- result-first error codes for invalid commands, spawn failures, exec failures, and pipe setup failures

Still deferred:

- async process handles
- streaming process handles

## Why Use It

- argv-first execution is the default, so spaces and shell metacharacters stay literal unless you explicitly choose `shell()`
- cwd and environment overrides apply only to the child process
- stdout, stderr, stdin, exit status, and timeout handling live in one small API
- nonzero child exits are reported as process outcomes, not library failures
- result values are structured enough for test code and tool code to branch on cleanly

## Package Goals

- keep the API small and predictable
- prefer argv-based execution over shell-string execution
- make tests easy to write
- stay useful for shells, editors, TUI apps, and developer tooling
- close a real ecosystem gap rather than mirroring `stdlib_system`

## Public API Shape

Primary module:

- `fgof_process`

Public types:

- `process_command`
- `process_options`
- `process_result`

Public procedures:

- `command`
- `shell`
- `run`

## Quick Start

```fortran
program demo_run
  use fgof_process, only : FGOF_PROCESS_OK, command, process_options, process_result, run
  implicit none

  character(len=6) :: argv(2)
  type(process_options) :: opts
  type(process_result) :: res

  argv = [character(len=6) :: "%s", "hello"]
  opts%capture_stdout = .true.

  res = run(command("printf", argv), opts)
  if (res%error_code /= FGOF_PROCESS_OK) error stop trim(res%error_message)
  if (res%exit_code /= 0) error stop "child command failed"

  print "(A)", res%stdout
end program demo_run
```

## Build And Test

```bash
fpm test
```

That is the baseline verification command locally and in CI.

## `command()` vs `shell()`

Choose `command()` when you already know the executable and argument list.

```fortran
res = run(command("git", [character(len=7) :: "status", "--short"]), opts)
```

This path does not interpret pipes, redirects, semicolons, or `$VARS`. They are passed through as literal argv values.

Choose `shell()` only when you need shell features such as pipelines or redirection.

```fortran
res = run(shell("printf 'hello' | sed 's/hello/world/'"), opts)
```

This path uses `/bin/sh -c` on POSIX systems.

## Common Patterns

Capture stdout:

```fortran
opts = process_options()
opts%capture_stdout = .true.
res = run(command("pwd"), opts)
```

Capture stderr:

```fortran
opts = process_options()
opts%capture_stderr = .true.
res = run(shell("printf 'oops' >&2"), opts)
```

Pipe stdin into a child:

```fortran
opts = process_options()
opts%stdin = "hello" // new_line("a")
res = run(shell("read value; test ""$value"" = ""hello"""), opts)
```

Run in a different working directory:

```fortran
opts = process_options()
opts%cwd = "/tmp"
res = run(command("pwd"), opts)
```

Set or unset child-only environment variables:

```fortran
opts = process_options()
opts%env_set = ["FGOF_MODE=test"]
opts%env_unset = ["OLD_ENV_FLAG"]
res = run(shell("env"), opts)
```

Enforce a timeout and keep partial output:

```fortran
opts = process_options()
opts%capture_stdout = .true.
opts%timeout_ms = 100
res = run(shell("printf 'begin'; sleep 2"), opts)
```

## Result Semantics

`run()` returns a `process_result` with three kinds of information:

- launch and completion state: `launched`, `completed`, `timed_out`, `exited_normally`
- child outcome: `exit_code`, `term_signal`, captured `stdout`, captured `stderr`
- library outcome: `error_code`, `error_message`, `elapsed_ms`

Important rule:

- a nonzero child `exit_code` is not a library error
- invalid input, pipe setup failure, spawn failure, exec failure, and timeout are library errors surfaced through `error_code`

## Supported Platforms

- macOS
- Linux
- GitHub Actions CI validates the package on `macos-latest` and `ubuntu-latest` with the GCC toolchain and `fpm v0.13.0`

## Current Boundaries

- v1 uses a direct POSIX backend on macOS and Linux.
- `stdlib_system` can inform naming and behavior, but is not a required dependency.
- Async process handles are explicitly deferred until after the sync-first release.

## Development Notes

- POSIX first: macOS and Linux
- standalone `fpm` package
- intended to remain independently versioned and releasable

## License

MIT
