# OrePAN2-S3 2.0.0 Release Notes

**Released:** Sun Aug 2, 2026  
**Author:** Rob Lauer \<rclauer@gmail.com\>

---

## Overview

Version 2.0.0 is a major release of `OrePAN2::S3` that rewrites the
`orepan2-s3` CLI from a monolithic bash script into a Perl modulino,
unifying all DarkPAN management commands under a single, cohesive
interface. This release also introduces a new
`OrePAN2::S3::Role::Upload` role, restructures the CLI command set,
and includes significant build infrastructure improvements inherited
from `CPAN::Maker::Bootstrapper`.

---

## Breaking Changes

### `orepan2-s3` Rewritten as a Perl Modulino

The `orepan2-s3` bash script (~470 lines) has been replaced with a
thin modulino wrapper that delegates entirely to `OrePAN2::S3`. All
command logic previously embedded in the bash script now lives in the
Perl module and its roles.

```bash
# New implementation (orepan2-s3)
MODULE_NAME=OrePAN2::S3
MODULE_PATH=$(MODULE_PATH="${MODULE_NAME//:://}.pm" perl -M$MODULE_NAME -e 'print $INC{$ENV{MODULE_PATH}};')
perl $MODULE_PATH "$@"
```

### `orepan2-s3-index` Script Removed

`bin/orepan2-s3-index` has been deleted. All functionality is now accessed directly via `orepan2-s3`.

### Command Interface Changes

| Old Command | New Command | Notes |
|---|---|---|
| `add {file}` | `upload {file}` | `add` remains as an alias |
| `upload` | `upload-index` | `upload` now means upload a distribution tarball |
| `index` | `upload-index` | Regenerates and uploads `index.html` |
| `inject {file}` | `inject {file}` | Now always uploads **and** indexes; `--upload-only` option removed |
| `delete {file}` | `delete {file}` | Unchanged |

### Removed CLI Options

`The `--upload` (`-u`) and `--upload-only` (`-U`) options have been
removed from the module's option set. The `inject` command now
unconditionally uploads and indexes.

---

## New Features

### New `OrePAN2::S3::Role::Upload` Role

A dedicated `Upload` role (`lib/OrePAN2/S3/Role/Upload.pm`) has been
added and consumed by `OrePAN2::S3`. The `upload` command now
exclusively handles uploading a distribution tarball to S3 without
touching the package index.

### `add` as an Alias for `upload`

```bash
orepan2-s3 add My-Dist-1.0.tar.gz   # still works
orepan2-s3 upload My-Dist-1.0.tar.gz # equivalent
```

### Enhanced `create-docs` Command

`cmd_create_docs` now extracts and bundles additional artifacts:

- Extracts `README.md` from the distribution tarball and uploads it as
  `README.html` (previously conditional — now always uploaded when
  `--upload` is set).
- Extracts `ChangeLog`, `CHANGES`, or `Changes` from the tarball.
- Creates a local `docs.tar.gz` archive containing `README.md`, the
  primary `.pm` file, and `ChangeLog`.

### New `upload-index` Command

A dedicated `upload-index` command has been added to explicitly upload
the generated `index.html` to the DarkPAN mirror root, distinct from
the `upload` (distribution tarball) command.

### `recommends` and `suggests` Dependency Tiers

Two new dependency files (`recommends`, `suggests`) are now tracked
and fed into `cpanfile` generation, supporting the full CPAN metadata
dependency tier model.

---

## Bug Fixes

### `cmd_download_orepan_index`: `rename` Replaced with `copy` + `unlink`

Cross-device moves (e.g., from `/tmp` to the working directory) would
silently fail with `rename`. This is now fixed using
`File::Copy::copy` followed by `unlink`.

```perl
# Before
rename $filename, $PACKAGE_INDEX;

# After
copy $filename, $PACKAGE_INDEX
  or die "ERROR: could not copy $filename -> $PACKAGE_INDEX\n";
unlink $filename;
```

### `cmd_inject` Refactored

`cmd_inject` now delegates upload logic to `cmd_upload` (via the new
Upload role) rather than duplicating the S3 `put_object` call inline.

---

## Build Infrastructure Changes

These changes are inherited from updated `CPAN::Maker::Bootstrapper`
managed includes.

### `perl.mk`

- Replaced `PODEXTRACT` with `PODCHECKER` (`podchecker`). Both `.pm`
  and `.pl` build rules now run `podchecker` as part of syntax
  validation.
- `tidy_on` and `critic_on` are now conditionally defined only when
  `perltidy`/`perlcritic` binaries are present on `PATH`.
- Added `PERLCRITIC_SEVERITY` (default: `5`) and `PERLCRITIC_THEME`
  (default: `pbp`) variables.
- `check-syntax` is now a proper `.PHONY` target that serves as a
  convenience alias for building all modules and scripts.
- Compile-skip list now supports a `compile.skip` file in addition to
  the `PERLWC_SKIP` make variable.
- Fixed a spurious double-redirect in `diff` invocation (`2>/dev/null
  2>&1` → `2>/dev/null`).
- `deps.mk` is now included unconditionally and depends on
  `.pm.in`/`.pl.in` source files rather than built targets,
  eliminating a chicken-and-egg dependency problem under parallel
  builds.

### `Makefile`

- Build tool references updated: `make-cpan-dist.pl` → `cpan-maker`,
  `md-utils.pl` → `markdown-render`, `scandeps-static.pl` →
  `scandeps-static`.
- `cpanfile` generation split into intermediate targets
  (`cpanfile.requires`, `cpanfile.recommends`, `cpanfile.suggests`)
  using `cpan-maker create-cpanfile`.
- Dependency scanning (`requires`, `recommends`, `suggests`,
  `test-requires`) now uses a grouped scan via `scandeps-static --raw`
  with `cmb filter` for skip/pin/preserve reconciliation.
- `deps.mk` is auto-generated by `cmb create-deps` from source `.pm.in` files.
- `SCAN` is automatically set to `OFF` when `scandeps-static` is not found.
- `CMB_UPDATE_CHECK` and `CMB_VERSION_DRIFT` variables added for
  bootstrapper version drift detection.
- `clean-local::` hook added for project-specific clean recipes.
- `build-ci` now mounts the local project directory into the Docker container.
- New `package` target: runs `make LINT=on SCAN=on` after a clean.
- New `install` target in `project.mk`: installs the built tarball via `cpanm`.
- `$(MODULE_PATH).in` now depends on `module.pm.tmpl` (order-only →
  explicit dependency) and removes the template after use.

### `update.mk`

- `update-available` now distinguishes between CPAN version checks
  (`CMB_UPDATE_CHECK`) and local file drift checks
  (`CMB_VERSION_DRIFT`), with configurable `warn`/`fail`/`ignore`
  behaviour.
- `post-update` now merges bootstrapper `.gitignore` entries into the
  project's `.gitignore` using `comm`.

### `git.mk`

- `git` target now supports `NO_COMMIT=1` to stage without committing.
- `git init` output suppressed.
- Makefile recipe converted to a single shell compound statement.

### `release-notes.mk`

- `release-notes` target simplified to delegate to `cmb
  release-notes`.

### `builder`

- Default installer flags expanded: `--no-prebuilt --show-build-log-on-failure --verbose`.
- Extra deps updated to `CPAN::Maker` and `CPAN::Maker::Bootstrapper` (version pins removed).
- Docker local run instructions updated to mount the project directory.
- `git clone` is skipped if the target directory already exists (supports mounted local builds).
- `git checkout` is skipped if inside a `.git` directory (supports mounted local builds).
- Build invocation changed to `make CMB_VERSION_DRIFT=ignore NO_ECHO=`.

### `.gitignore`

Added:
- `**/*.checked`
- `**/*.raw`
- `buildspec.yml.current`

---

## Documentation

- `README.md.in` corrected: `F</index.html>` (POD syntax) replaced
  with `/index.html` (Markdown).
- Added a note that CloudFront cache invalidation requires appropriate
  IAM permissions.
- Replaced `See C<perldoc OrePAN2::S3> for more details` with a
  cleaner Markdown equivalent.
- `README.md` regenerated from `README.md.in` via `Markdown::Render`.
- Module POD (`OrePAN2::S3`) substantially updated:
  - Synopsis updated to reflect the new command structure.
  - Description updated to note the modulino rewrite.
  - Options and Commands sections rewritten to reflect the new CLI.
  - Added a `ROLES CONSUMED` section documenting all four consumed roles.

---

## Dependency Changes

### `cpanfile`

- `OrePAN2::Lite` entry sorted into alphabetical order (no version change).
- No new runtime dependencies added.

---

## Upgrade Notes

- Users relying on the `--upload` or `--upload-only` flags must update
  their scripts. Use `upload` for tarball-only upload and `inject` for
  upload + index.
- Users calling `orepan2-s3-index` directly must migrate to `orepan2-s3` subcommands.
- The `upload` command no longer uploads `index.html`; use
  `upload-index` for that purpose.
- Wrappers or automation that parsed `orepan2-s3` bash script
  internals will need to be updated.
