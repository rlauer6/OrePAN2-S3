# OrePAN2::S3 1.0.6 Release Notes

## Bug Fixes

**`README.md` documentation missing from uploaded distributions.** The
`upload_html` method was passing `content` for both POD and README
uploads, but `README.md` files are Markdown and need to be rendered
differently from POD. The method now accepts a `markdown` argument -
when present, `Text::Markdown::Discount` renders it directly rather
than passing it through `DarkPAN::Utils::Docs`. README files now
render correctly in the DarkPAN index.

**`distribution` context missing from POD upload.** The
`cmd_create_docs` method was not passing the distribution name to
`upload_html`, preventing per-distribution `perldoc_url_prefix`
configuration from taking effect. The distribution basename is now
passed through and matched against the `perldoc_url_distros`
configuration list.

**`perldoc_url_prefix` now falls back to MetaCPAN.** When no
per-distribution URL prefix is configured, POD links now point to
`https://metacpan.org/pod` rather than the DarkPAN's own URL
prefix. Distributions not in your `perldoc_url_distros` list will have
their module links resolved on MetaCPAN.

**`fetch_template` default template handling fixed.**
`slurp_file($template // $fh)` was passing a filehandle as the default
which could fail depending on context. The logic is now explicit -
`'default'` reads from `*DATA`, any other value reads from the named
file path.

## New Features

**`README.md.in` support.** If `README.md.in` exists in the project
root, `md-utils.pl` is used to generate `README.md` with
table-of-contents processing and `@TOC_BACK@` substitution. If no
`.in` file exists, `pod2markdown` is used as before. `README.md` is
added to `CLEANFILES` since it is now always a generated artifact.

## New Dependencies

- `Text::Markdown::Discount` - Markdown to HTML rendering for README
  documentation
  - `List::Util qw(pairs)` - used for iterating `perldoc_url_distros`
    configuration entries
