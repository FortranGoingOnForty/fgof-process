# fgof-process

POSIX-first process and subprocess helpers for modern Fortran applications.

`fgof-process` is intended to be a small, standalone library that gives Fortran tools a more ergonomic process API than raw `execute_command_line` or ad hoc C interop.

Initial scope:

- argv-first command construction
- synchronous process execution
- environment overrides
- working-directory overrides
- stdout and stderr capture
- exit-status reporting
- timeout-aware execution

Future scope:

- streaming process handles
- async spawn and wait
- signal helpers
- PTY-friendly integration points for a future `fgof-pty`

## Status

Early scaffold.

This repository is being created as the first package in the FortranGoingOnForty reusable library family and is intended to be consumed standalone or via the umbrella catalog repo at `lib-modules`.

## Package Goals

- keep the API small and predictable
- prefer argv-based execution over shell-string execution
- make tests easy to write
- stay useful for shells, editors, TUI apps, and developer tooling

## Planned API Shape

Primary module:

- `fgof_process`

Initial public types:

- `process_command`
- `process_result`
- `process_options`

Initial public procedures:

- `command`
- `run`

## Development Notes

- POSIX first: macOS and Linux
- standalone `fpm` package
- intended to remain independently versioned and releasable

## License

TBD
