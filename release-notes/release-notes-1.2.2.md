# OrePAN2::S3 Release Notes

## 1.2.2

### Summary

Introduces an upload-only mode that decouples tarball upload from
index maintenance. When `--upload-only` is set, `orepan2-s3 inject`
uploads the tarball to S3 and returns immediately - the DarkPAN index
is not updated. This supports a Lambda-based indexing architecture
where an S3 `ObjectCreated` trigger fires a Lambda handler that
performs the indexing asynchronously. The upload-only flag is optional;
standard injection (upload + index) continues to work unchanged.

---

### New Features

**`--upload-only` / `-u` flag.** The `inject` command now accepts
`--upload-only`. When set the tarball is uploaded to the configured
author path and the command exits without updating `02packages` or
invalidating the CloudFront cache. The `add` command similarly passes
this flag through to `orepan2-s3-index`.

**`OrePAN2::S3::Indexer`.** New class intended for use inside a Lambda
handler. Locates the config file via a candidate list that includes
`~/.orepan2-s3.json`, `/var/task/orepan2-s3.json`, and `orepan2-s3.json`
in the working directory (covering both local and Lambda execution
environments). Consumes `OrePAN2::S3::Role::Inject` and
`OrePAN2::S3::Role::UploadArtifacts`.

**`OrePAN2::S3::Role::Inject` expanded.** Three methods moved from
`OrePAN2::S3` into the role, making them available to `Indexer` and
any other consumer:

- `scan_provides` - reads a tarball and extracts the `provides` map from `META.json`
- `fetch_orepan_index` - downloads the current `02packages.details.txt.gz` to a temp file
- `update_index` - fetches the index, applies a callback, re-compresses and uploads

The injection flow is refactored into:
- `cmd_inject` - uploads the tarball; returns early if `--upload-only`
- `_index_tarball` - performs the provides scan and index update;
  called only when not in upload-only mode

---

### Bug Fixes

**`DEFAULT_CONFIG` undef when `$ENV{HOME}` is not set.** In Lambda
execution environments `$HOME` is not defined. The constant
initialization now guards against undef:

```perl
Readonly::Scalar our $DEFAULT_CONFIG =>
  sprintf '%s/%s', $ENV{HOME} // q{}, '.orepan2-s3.json';
```

**`create_index` return value was misleading.** The `add` and `inject`
commands previously gated `invalidate_cache` on the return value of
`create_index`, which always returned a true value. The conditional
has been removed - cache invalidation now runs unconditionally after
a successful index creation.

**`invalidate_cache` silently discarded errors.** The function now
captures CloudFront output to a temp file and prints it to STDERR
regardless of success or failure, making CloudFront errors visible
in logs.

**`cleanup` postfix `if` replaced with block.** `test -n "$TEMP_DIR"
&& rm -rf "$TEMP_DIR"` replaced with a proper `if [[ ... ]]` block.

---

### Changes

**`scan_provides` moved from `OrePAN2::S3` to `OrePAN2::S3::Role::Inject`.**
`OrePAN2::S3` no longer defines `scan_provides` directly.

**Command table keys quoted.** The `main` dispatch table now uses
quoted string keys (`'inject'`, `'create'`, `'delete'` etc.) for
consistency.

**`create-index` alias added.** The `create` command is now also
reachable as `create-index` for clarity.

**`Log::Log4perl` added as a required dependency.**

---

## 1.2.1

See `release-notes/release-notes-1.2.1.md`.
