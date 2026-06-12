## OrePAN2::S3 1.2.3 Release Notes

**New Features**
- Added `dist_dir` accessor, set during `init` via
  `File::ShareDir::dist_dir`, pointing to the package's installed
  share directory; exposed as a CLI option.
- `fetch_template`: relative template paths from config are now
  resolved against `dist_dir` (absolute paths used as-is).

**Bug Fixes**
- `cmd_upload_artifacts`: relative source paths are now resolved
  against `dist_dir` rather than the current working directory,
  allowing artifacts to be uploaded from the distribution's share
  directory in addition to fully-qualified paths.

**Dependencies**
- Added `File::ShareDir` 1.118.
