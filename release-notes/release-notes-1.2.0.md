## OrePAN2::S3 1.2.0 — Performance & Architecture

### Summary

This release is a significant performance improvement focused on
eliminating unnecessary S3 sync operations and replacing the
heavyweight `Amazon::S3` dependency with the lighter
`Amazon::S3::Lite`. The result is a **79% reduction in wall-clock
time** for the `add` command (36s -> 7.5s).

### What Changed

**New commands**

- `inject` - uploads a tarball to S3 and updates the DarkPAN index in
  a single in-process operation, replacing the former
  `orepan2-inject` + `aws s3 sync` workflow
- `delete` - removes a distribution from S3 and reindexes without
  syncing the entire repository locally
- `upload-artifacts` - uploads static assets (CSS, JS, etc.) listed in
  the config file using inferred MIME types, replacing `aws s3 cp`
  subprocesses. Computes an MD5 hash of each file on upload and stores
  it in the config; subsequent runs skip unchanged files automatically

**Dependency changes**

- `Amazon::S3` → `Amazon::S3::Lite` - eliminates `LWP::UserAgent` and
  reduces cold-start overhead
- Added: `CPAN::Meta`, `Digest::MD5`, `IO::Compress::Gzip`,
  `LWP::MediaTypes`, `Role::Tiny`, `Role::Tiny::With`

**Architecture**

- New roles: `OrePAN2::S3::Role::Inject`, `OrePAN2::S3::Role::Delete`,
  `OrePAN2::S3::Role::UploadArtifacts`
- New shared methods: `update_index`, `scan_provides`,
  `_packages_for_archive`, `init_s3`, `write_config`
- Heavy modules lazy-loaded at point of use: `Archive::Tar`,
  `CPAN::Meta`, `DarkPAN::Utils`, `DarkPAN::Utils::Docs`,
  `OrePAN2::Index`, `Template`, `Text::Markdown::Discount`
- `bash` wrapper reduced to orchestration only - S3 operations moved
  entirely into Perl
- `Amazon::S3::Lite` bug fixes for real S3 compatibility (masked by
  LocalStack during development): missing `x-amz-content-sha256`
  header on `PUT` requests, and incorrect session token resolution for
  STS/IAM credentials

**New option**

- `-b, --bucket-name` - overrides bucket name from config file

**Configuration**

- New `author_path` key - overrides the default `D/DU/DUMMY` S3 path
  for distribution storage
- `index.files` format extended - entries may now be either a flat
  destination string (existing format, still supported) or a hashref
  with `dest` and `md5` keys. The MD5 is written automatically by
  `upload-artifacts` on first run and used to skip unchanged files on
  subsequent runs:

```json
"files": {
  "/path/to/bedrock-repo.css": {
    "dest": "/css/bedrock-repo.css",
    "md5": "d41d8cd98f00b204e9800998ecf8427e"
  }
}
```

### Timing

| Operation | Before | After |
|-----------|--------|-------|
| `add`    | 36.1s  | 7.5s  |
| `delete` | ~36s   | ~9s   |
