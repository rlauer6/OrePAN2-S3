## OrePAN2::S3 1.2.1 — Build Infrastructure & Dependency Cleanup

### Summary

This is a maintenance release focused on removing unnecessary
dependencies, aligning `buildspec.yml` key names with the current
`CPAN::Maker` conventions, and introducing a fully self-contained CI
build pipeline. No runtime behavior changes.

### What Changed

**Dependency cleanup**

- Removed `YAML` - was unused at runtime; the one internal caller has
  been eliminated from `OrePAN2/S3.pm.in`
- Removed `Archive::Tar` and `IO::Compress::Gzip` - both are Perl
  core modules and do not belong in `requires`/`cpanfile`
- Bumped `Amazon::Credentials` to `1.3.0`
- Bumped `CLI::Simple`, `CLI::Simple::Constants`, `CLI::Simple::Utils`
  to `2.0.1`

**Build infrastructure**

- Added `builder` - a self-contained CI shell script suitable for
  GitHub Actions and other runners; supports `cpm` and `cpanm`,
  DarkPAN mirror injection via `build-mirrors`, optional
  `Perl::Tidy`/`Perl::Critic` passes, and local Docker replay via
  `make build-ci`
- Added `.github/workflows/build.yml` - GitHub Actions workflow using
  `debian:trixie`; pre-installs `git` before checkout to avoid the
  dubious-ownership fatal error in containers
- Added `build-mirrors` - seeds the DarkPAN resolver URL
  (`https://cpan.openbedrock.net/orepan2`) for CI dependency
  resolution
- Added `make workflow` target - installs `builder`,
  `build-requires`, and `.github/workflows/build.yml` from the
  installed `CPAN::Maker::Bootstrapper` share directory
- Added `make build-ci` target - runs the build locally in Docker
  against the current branch, logging to a timestamped build log
- Added `make update-available` target - checks whether a newer
  `CPAN::Maker::Bootstrapper` is available on CPAN and reports it;
  runs automatically as part of the default `all` target
- Added `make test` and `make check` targets

**`buildspec.yml` key normalization**

- Renamed `pm_module` → `pm-module`, `exe_files` → `exe-files`,
  `test_requires` → `test-requires` to match current `CPAN::Maker`
  naming conventions

**`update.mk` improvements**

- `post-update` now uses `chmod -w` (write-protect after copy) rather
  than `chmod +w` (which was a no-op permission grant before the copy)
- `perl ... || true` guard prevents `make` from aborting when
  `CPAN::Maker::Bootstrapper` is not installed
- `update` target now conditionally refreshes `builder` if present

**`Makefile` fixes**

- `find-files` macro now iterates over multiple source directories
  safely, guarding against missing dirs
- `scan-deps` passes `min-perl-version` from `buildspec.yml` to
  `scandeps-static.pl` via the new `-m` flag
- `buildspec.yml.tmpl` and `test.t.tmpl` targets hardened against
  missing share directory
- Template substitution for `$(MODULE_PATH).in` fixed to reference
  `module.pm.tmpl` directly rather than `$<`
- `make-cpan-dist.pl` now called with `-l $(LOG_LEVEL)` for
  configurable verbosity

**Project layout**

- Release notes relocated from project root into `release-notes/`
  subdirectory
