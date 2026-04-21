# Roadmap

## Current focus

- harden the synchronous v1 surface with behavior tests
- document the argv-first contract clearly enough that tool authors can adopt it quickly
- add Linux and macOS CI so `fpm test` is the baseline trust signal

## v0.1

- establish the stable public API
- implement synchronous argv-first execution
- add shell convenience via explicit `shell()`
- support cwd, env, stdin, stdout, stderr, and timeouts
- ship a documented sync-first library that tool authors actually want to use

## v0.2

- async process handles
- richer process control
- signal helpers
- stronger process-fixture testing support

## v0.3

- companion packages such as `fgof-proc-test`
- possible PTY-facing integrations
