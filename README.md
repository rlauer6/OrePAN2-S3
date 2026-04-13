# NAME

    OrePAN2::S3 - Manage a DarkPAN CPAN mirror on Amazon S3

# SYNOPSIS

    # via the bash wrapper (recommended)
    orepan2-s3 add My-Dist-1.0.tar.gz
    orepan2-s3 index

    # or directly via the modulino
    orepan2-s3-index create --upload

# DESCRIPTION

This class is used to add distributions to your own DarkPAN
repository housed on Amazon's S3 storage. It leverages [OrePAN2](https://metacpan.org/pod/OrePAN2) to
create and maintain your own DarkPAN repository. You can read more
about setting up a DarkPAN on Amazon using S3 + Cloudfront
[here](https://github.com/rlauer6/OrePAN2-S3/blob/master/README.md).

You can read more about creating a secure static website using Amazon
S3 [here](https://blog.tbcdevelopmentgroup.com/2025-02-18-post.html).

# USAGE

    orepan2-s3 options command

Perl script for maintaining a DarkPAN mirror using S3 + CloudFront.

_NOTE: `orepan2-s3` is the bash script that calls this Perl class
that doubles as a modulino.  The documentation here refers to the
script (not the class)_.

## Options

    -h, --help           Display this help message
    -c, --config-file    Name of the configuration file (default: ~/.orepan2-s3.json)
    -o, --output         Name of the output file
    -p, --profile        Your AWS profile if not provided in configuration
    -n, --profile-name   Name of a profile inside the config file
    -t, --template       Name of a template that will be used as the index.html page
    -d, --distribution   Path to distribution tarball
    -u, --upload         Upload files after processing (for create-index, create-docs)
    -U, --url            Cloudfront URL

## Commands

- create - Create a new `index.html` from the mirror's manifest file.
- download - Download the mirror's manifest file (`02packages.details.txt.gz`).
- show - Print the manifest file to STDOUT or a file.
- upload - Upload the index.html file to the mirror's root.
- dump-template - Outputs the default index.html template.
- create-docs - parse distribution looking for a README.md and/or pod
- invalidate-index - _not currently implemented_

## Notes

- The preferred way of using this utility is through the bash wrapper.

    _The following commands are available only through the `orepan2-s3`
    bash wrapper, not the modulino directly:_

    - add {file} - inject a tarball into the repository and re-index
    - delete {file} - remove a distribution and re-index
    - invalidate - invalidate the CloudFront cache

## Configuration File

The configuration file for `orepan2-s3` is a JSON file that can
contain multiple profiles (or none). Each profile represents a DarkPAN
S3 repository. The format should look something like this:

    {
        "default" : "bedrock",
        "tbc" : {
            "AWS": {
                "profile" : "prod",
                "region" : "us-east-1",
                "bucket" : "tbc-cpan-mirror",
                "prefix" : "orepan2"
            },
            "CloudFront" : {
                "DistributionId" : "E2ABCDEFGHIJK"
            }
        },
        "bedrock" : {
            "index" : {
                "template" : "/path/to/template",
                "files": {
                   "src" : "dest"
                }
            },
            "AWS": {
                "profile" : "prod",
                "region" : "us-east-1",
                "bucket" : "cpan.openbedrock.net",
                "prefix" : "orepan2"
            },
            "CloudFront" : {
                "DistributionId" : "E2JKLMNOPQRXYZ",
                "InvalidationPaths" : [],
                "url" : "https://cpan.openbedrock.net/orepan2"
            }
        }
    }

Each profile can contain the keys described below. If you only have one
profile you don't need to place it in a 'default' section.

The value for the 'default' key can be the name of a profile or a hash
of the profile.

- index

    This section allows you to create custom template for the DarkPAN home page.

    - template

        The name of a template file that will be parsed and uploaded as
        `/index.html`. If you do not provide a template file a default
        template is used. The default template is a [Template::Toolkit](https://metacpan.org/pod/Template%3A%3AToolkit) style
        template. To see the default template use the `dump-template` command
        to the `orepan2-s3-index` script.

            orepan2-s3-index dump-template

        The templating process is provided with these variables:

        - utils

            A blessed reference to an object with one method (`module_name`) that
            returns a version of the module name suitable for use as unique CSS id.

        - repo

            A hash of key value pairs where the key is the name of a DarkPAN
            distribution and value is an array or arrays. Each array is of the
            form:

                [0] => Perl module name
                [1] => Module version

        - localtime

            The current time and date as a string.

        - pod\_links

            A hash where the keys are distribution names and the values are links
            to the POD for a module.

        - readme\_links

            A hash where the keys are distribution names and the values are links
            to a README for a module.

            _NOTE: Sometimes the README and the POD will contain the same information._

    - files

        A hash of source/destination pairs that specify additional files you
        want uploaded to your S3 bucket.

        Example:

            "files": { 
               "/home/rlauer/git/some-project/foo.css" : "/css/foo.css",
               "/home/rlauer/git/some-project/foo.js" : "/javascript/foo.js"
            }

- AWS
    - profile

        The IAM profile that allows access to the S3 bucket and CloudFront.

    - region

        AWS region. Default: us-east-1

    - bucket

        S3 bucket name

    - prefix

        The prefix where the CPAN distribution files will be stored. Default: orepan2.
- CloudFront

    _NOTE: Your profile must have the ability to invalidate the CloudFront cache!_

    - DistributionId

        CloudFront distribution id

    - InvalidationPaths

        `OrePAN2::S3` is designed to work with CloudFront + Amazon
        S3. CloudFront is a CDN and will read content from your S3 bucket when
        clients make HTTP requests. CloudFront will cache content to avoid
        costly reads to the S3 bucket. If you change some of the static assets
        (like the index page) you may want to invalidate the cache to see
        your new assets. You could wait until the cache is updated (the
        default time is 24 hours)...but why?  The script will automatically
        invalidate the cache for you if you tell it what assets to invalidate
        when you add a new distribution.

        An array of additional paths to invalidate when adding new distributions.

        _Note: There is no additional charge for adding additional
        paths. Each invalidation batch is considered as one billing unit by
        AWS. However, keep in mind you get 1000 invalidation paths for free
        each month. Thereafter each path costs $0.005 per path._

- custom\_sections

    This section contains key/value pairs where the key is the name of a
    variable that will be exposed to your template and the values
    are a two element array that contains a regular expression and
    possible regexp flags. The script will use the regexp to filter your
    distributions and add them to a hash whose name is the key you
    provided.

    The purpose of this section is to allow you to possibly organize your
    distributions under possible HTML headings.

    Example:

        "custom_sections" : {
            "plugins" : ["^BLM\-(?!Startup)", "xsm"],
            "app_plugins" : ["^BLM\-Startup", "xsm"],
         }

    ...then in your template:

            <h1>Application Plugin Index</h1>
            
        [% FOREACH distribution = app_plugins.sort %]
              <h2>
               <span class="collapse-section-icon">&#9660;</span>
               [% distribution %]
               [% IF readme_links.$distribution %]
               <a title="README"  class='doc-link' href="[% readme_links.$distribution %]"><span class="material-symbols-outlined">docs</span></a>
               [% END %]
               [% IF pod_links.$distribution %]
               <a title="pod" class='doc-link' href="[% pod_links.$distribution %]"><span class="material-symbols-outlined">docs</span></a>
               [% END %]
              </h2>
        
              <ul class="collapsable" id="[% utils.module_name(distribution) %]">
        [% FOREACH module IN app_plugins.$distribution %]
                <li>[%  module.0 %]</li>
        [% END %]
              </ul>
        [% END %]
           <hr>

# AUTHOR

Rob Lauer - <rlauer@treasurersbriefcase.com>

# SEE ALSO

[OrePAN2](https://metacpan.org/pod/OrePAN2), [Amazon::S3](https://metacpan.org/pod/Amazon%3A%3AS3), [DarkPAN::Utils](https://metacpan.org/pod/DarkPAN%3A%3AUtils), [CLI::Simple](https://metacpan.org/pod/CLI%3A%3ASimple), [Template](https://metacpan.org/pod/Template)

# LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
