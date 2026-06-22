# OrePAN2::S3 1.2.4 Release Notes

## Overview

1.2.4 is a dependency-only release that replaces `OrePAN2` with
`OrePAN2::Lite` as the indexing dependency, eliminating `LWP::UserAgent`
and its transitive dependencies from the Lambda image. Combined with the
`Amazon::API` 2.3.x dependency chain (which replaced `AWS::Signature4` with
`Amazon::Signature4::Lite`), the deployed image based on
`OrePAN2::S3::Handler` maintains its 158MB footprint
while carrying all the new functionality added across 1.2.x.

No application code was changed.

---

## Dependency Changes

### OrePAN2::Lite replaces OrePAN2

`OrePAN2` depends on `LWP::UserAgent` (via `OrePAN2::Auditor`), which pulls
in the full `libwww-perl` stack — `HTML::Parser`, `WWW::RobotRules`,
`HTTP::Negotiate`, and associated C-compiled XS modules — none of which are
needed for DarkPAN indexing and injection in a Lambda context.

`OrePAN2::Lite` is a fork of `OrePAN2` with `OrePAN2::Auditor` ported to
`HTTP::Tiny` (already a core dependency of the ecosystem) and `LWP::UserAgent`
removed from its dependency list. All indexing and injection functionality
is preserved; only the auditing CLI tool's HTTP backend changes.

### OrePAN2::Index removed from requires

`OrePAN2::Index` (a module bundled within the `OrePAN2` distribution, not
separately installable) was previously declared as an explicit `requires`
entry, which caused `cpm`/`cpanm` to fail when it couldn't resolve it as a
standalone package. It is now listed in `requires.skip`, preventing the
dependency resolver from attempting to install it independently while still
allowing code that `use`s it to work at runtime (it arrives transitively
via `OrePAN2::Lite`).

### Version bumps

- `Amazon::S3::Lite` → 1.2.2
- `CLI::Simple` → 2.0.3

---

## Upgrade Notes

Ensure `OrePAN2::Lite` 1.0.0 or later is available in your CPAN mirror
before building Lambda images from this version. If using this project's
DarkPAN, `OrePAN2::Lite` 1.0.0 is available there.
