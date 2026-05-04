# OrePAN2::S3 1.1.0 Release Notes

## Overview

This release migrates the project to `CPAN::Maker::Bootstrapper`,
bumps `CLI::Simple` to 2.0.0, and fixes two `eval`-based regex
vulnerabilities introduced in 1.0.6.

## Security Fix

**`eval`-based regex compilation replaced throughout.** Two locations
in 1.0.6 used `eval "qr/$qr/$flags"` to compile dynamic regexes from
configuration values - a code injection risk if the config file is
tampered with. Both are now replaced with the safe `(?flags:pattern)`
inline syntax:

```perl
# before
$qr = eval "qr/$qr/$flags";

# after
my $qr = qr/(?$flags:$pattern)/;
```

Affected code paths: `upload_html` (per-distribution
`perldoc_url_prefix` matching) and `cmd_create_index` (custom sections
matching).

## Build System Migration

**Migrated to `CPAN::Maker::Bootstrapper`.** The project now uses the
standard bootstrapper build infrastructure with `.includes/` make
files - `perl.mk`, `git.mk`, `help.mk`, `release-notes.mk`,
`update.mk`, `upgrade.mk`, `version.mk`.

**`cpanfile` added.** Generated from `requires` for `cpanm
--installdeps .` compatibility.

**`provides` file removed.** Now managed by `buildspec.yml`.

**`ChangeLog` target fixed.** Now uses `test -e $@ || touch $@` - only
creates the file if it doesn't exist, preventing unnecessary timestamp
updates that triggered tarball rebuilds.

**`buildspec.yml` now order-only prerequisite.** Prevents
`buildspec.yml.tmpl` and `test.t.tmpl` from causing spurious rebuilds
when the targets already exist.

**`modulino` target improvements.** `ALIAS` variable supported for
custom wrapper script naming. `MODULINO_WRAPPER` is now correctly set
in the generated bash wrapper for `CLI::Simple` 2.0.0 bash completion
support.

**`README.md` now includes TOC.** When generated from POD via
`pod2markdown`, a `@TOC@` header is prepended and `md-utils.pl`
processes it to produce a table of contents.

**Scan progress output.** `scandeps-static.pl` now prints
`Scanning...{file}` to stderr for each file scanned, providing
progress feedback on larger projects.

## Dependency Updates

- `CLI::Simple` bumped to 2.0.0
- `Amazon::Credentials` bumped to 1.2.1
- `Archive::Tar` bumped to 3.02_001
- `Template` pinned to 3.102
- `YAML` bumped to 1.31
- `test-requires` cleared - `Test::More` is core
