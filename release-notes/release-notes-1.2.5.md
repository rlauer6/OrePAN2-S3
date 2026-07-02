# OrePAN2::S3 Release Notes — v1.2.5

**Released:** Thu Jul 2, 2026
**Author:** Rob Lauer \<rclauer@gmail.com\>

---

## Overview

Version 1.2.5 is a performance and correctness release focused on
improving startup efficiency through document index pre-loading,
fixing filesystem compatibility issues in containerised environments,
and resolving path resolution bugs for configuration-relative template
and artifact files.

---

## What's New

### Performance Improvement: Document Index Pre-loading

The most significant change in this release is the replacement of
per-object `head_object` S3 API calls with an in-memory document index
cache.

- **`_init_doc_index` (new method):** On startup, all objects under
  the `docs/` prefix are listed once using `list_all_objects_v2` and
  loaded into the module-level `%DOC_INDEX` hash.
- **`look_for_object` (rewritten):** Now performs a simple hash lookup
  against `%DOC_INDEX` instead of issuing a `head_object` request to
  S3 for each document. This significantly reduces API call overhead
  when building index pages with many distributions.
- **`_upload_html` (updated):** Newly uploaded HTML documents are
  immediately added to `%DOC_INDEX`, keeping the cache consistent
  without requiring a restart.
- **`init` (updated):** Calls `_init_doc_index` as part of the
  standard initialisation sequence.

### Container / Read-Only Filesystem Fix

- **`fetch_orepan_index`:** Temporary files are now explicitly created
  in `/tmp` via the `DIR => '/tmp'` option to
  `File::Temp::tempfile`. This resolves failures in container
  environments where the working directory may be on a read-only
  filesystem.

### Configuration Path Handling

- **`fetch_config` (updated):**
  - Now returns early (no-op) if a config has already been loaded, preventing redundant re-reads.
  - Resolves the config file path to an absolute path using `Cwd::abs_path` before use, ensuring consistent behaviour when the process changes working directory.

### Template and Artifact Path Resolution

Previously, relative paths for templates and upload artifacts were
resolved against the distribution's shared data directory
(`dist_dir`). They are now resolved relative to the directory
containing the configuration file, which is more intuitive and
practical.

- **`fetch_template`:** Relative `template` paths in the config are
  now joined with `dirname(config_file)` rather than `dist_dir`.
- **`OrePAN2::S3::Role::UploadArtifacts::cmd_upload_artifacts`:**
  Relative source file paths are now resolved against
  `dirname(config_file)` rather than `dist_dir`.

---

## Dependency Changes

| Dependency | Previous | New |
|---|---|---|
| `Amazon::S3::Lite` | 1.2.2 | **1.2.3** |

The minimum required version of `Amazon::S3::Lite` has been bumped to **1.2.3** in both `cpanfile` and `requires`.

---

## Files Changed

- `VERSION`
- `cpanfile`
- `requires`
- `lib/OrePAN2/S3.pm.in`
- `lib/OrePAN2/S3/Role/UploadArtifacts.pm.in`

---

## Upgrading

No breaking changes are introduced in this release. Users running
`OrePAN2::S3` in container or read-only filesystem environments are
encouraged to upgrade to resolve the `/tmp` tempfile issue. Users with
large DarkPAN repositories will benefit immediately from the reduced
number of S3 API calls during index generation.
