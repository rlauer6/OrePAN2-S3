# Release Notes — OrePAN2-S3 2.0.1

## Overview

This release delivers improvements to upload safety, index creation
reliability, and META extraction correctness, along with a build
system update.

---

## What's New

### Dirty-Check Protection on Upload

The `upload` command (alias: `add`) now checks whether the
distribution being uploaded was built from uncommitted changes before
proceeding.

- If the tarball contains a module with a `$GIT_DIRTY` variable marked
  as dirty, the upload is blocked by default.
- Use `--force` to override and upload anyway (a warning is printed).
- Use `--no-dirty-check` to disable the check entirely.
- Dirty checking is **enabled by default**.

Two new package-level variables, `$GIT_SHA` and `$GIT_DIRTY`, are now
embedded in `OrePAN2::S3` at build time to support this feature.

### New `--force` Option

A `--force` flag has been added to allow uploading distributions that
fail the dirty check. Without it, a dirty distribution causes the
upload to abort with an error message.

### Improved Error Reporting in `inject`

- `cmd_inject` now propagates the result of `_index_tarball` — if
  indexing fails, the command returns a failure exit code rather than
  silently succeeding.
- `_index_tarball` reports an explicit error when `scan_provides`
  returns nothing.

### Fixed META Extraction for Prefixed Tarballs

`scan_provides` previously assumed a specific tarball layout and
failed silently on tarballs where `Archive::Tar` entries carry a
`prefix` attribute separate from the `name`. The extraction logic now
handles both layouts correctly.

Error reporting from `scan_provides` has been improved — distinct
error messages are emitted for:
- No META file found in the tarball
- META file found but no `provides` section
- META file found but could not be loaded

### Index Creation Logging Reduced

Distribution-level logging in `cmd_create_index` has been moved from
`info` to `debug` level, reducing noise in normal operation. A warning
about unresolvable distribution names is now logged via the logger
rather than written directly to `STDERR`.

### Build System Updated

Managed build files have been updated by `CPAN::Maker::Bootstrapper`.

---

## Bug Fixes

- Fixed the `builder` script, which incorrectly skipped branch
  checkout when running inside a `.git` repository (condition was
  inverted).
- `send_output` and `cmd_create_index` now return `$SUCCESS`
  consistently rather than a bare `0`.

---
