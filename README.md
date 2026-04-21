# fgof-process

POSIX-first process and subprocess helpers for modern Fortran applications.

`fgof-process` is intended to be a small, standalone library that gives Fortran tools a more ergonomic process API than raw `execute_command_line`, thin POSIX wrappers, or experimental process surfaces that still feel too low-level for real tooling.

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

Sprint 00 and 01 scaffold.

This repository is the first package in the FortranGoingOnForty reusable library family and is intended to be consumed standalone or via the umbrella catalog repo at `lib-modules`.

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

## Current Boundaries

- Direct POSIX backend is planned for v1.
- `stdlib_system` can inform behavior, but is not a required backend.
- Async process handles are explicitly deferred until after the sync-first release.

## Development Notes

- POSIX first: macOS and Linux
- standalone `fpm` package
- intended to remain independently versioned and releasable

## License

MIT
