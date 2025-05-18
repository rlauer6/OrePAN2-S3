package OrePAN2::S3;

use strict;
use warnings;

use Amazon::Credentials;
use Amazon::S3;
use Archive::Tar;
use Template;
use Carp;
use CLI::Simple;
use Data::Dumper;
use DarkPAN::Utils qw(parse_distribution_path);
use DarkPAN::Utils::Docs;
use English qw(-no_match_vars);
use File::Basename qw(basename);
use File::Temp qw(tempfile);
use JSON;
use Scalar::Util qw(openhandle);
use OrePAN2::Index;
use YAML;

use Readonly;

Readonly::Scalar our $PACKAGE_INDEX  => '02packages.details.txt.gz';
Readonly::Scalar our $DEFAULT_CONFIG => $ENV{HOME} . '/.orepan2-s3.json';
Readonly::Scalar our $TRUE           => 1;
Readonly::Scalar our $FALSE          => 0;

use parent qw(CLI::Simple);

our $VERSION = '0.05';

caller or __PACKAGE__->main();

########################################################################
sub slurp_file {
########################################################################
  my ( $file, $json ) = @_;

  local $RS = undef;

  my $content;

  if ( openhandle $file) {
    $content = <$file>;
  }
  else {
    open my $fh, '<', $file
      or die "could not open $file for reading: $OS_ERROR";

    $content = <$fh>;

    close $fh;
  }

  return JSON->new->decode($content)
    if $json;

  return wantarray ? split /\n/xsm, $content : $content;
}

########################################################################
sub fetch_config {
########################################################################
  my ( $self, $profile ) = @_;

  $profile //= 'default';

  my $file = $self->get_config_file;

  die "no config file specified\n"
    if !$file;

  die "$file not found\n"
    if !-e $file;

  my $config = eval { return JSON->new->decode( scalar slurp_file($file) ); };

  die "could not read config file ($file)\n$EVAL_ERROR"
    if !$config || $EVAL_ERROR;

  if ( $config->{$profile} ) {
    $config = $config->{$profile};
  }

  $self->set_config($config);

  return $config;
}

########################################################################
sub get_bucket {
########################################################################
  my ($self) = @_;

  my $config = $self->get_config;

  my ( $bucket_name, $prefix, $profile ) = @{ $config->{AWS} }{qw(bucket prefix profile)};

  my $s3 = $self->get_s3;

  my $credentials = $self->get_credentials;

  if ( !$s3 ) {
    $s3 = Amazon::S3->new( credentials => $credentials );
    $self->set_s3($s3);
  }

  return $s3->bucket($bucket_name);
}

########################################################################
sub fetch_orepan_index {
########################################################################
  my ( $self, $unlink ) = @_;

  $unlink //= $TRUE;

  my ( $fh, $filename ) = tempfile(
    'XXXXXX',
    SUFFIX => '.gz',
    UNLINK => $unlink,
  );

  my $config = $self->get_config;

  my $object = sprintf '%s/modules/%s', $config->{AWS}->{prefix}, $PACKAGE_INDEX;

  my $bucket = $self->get_bucket;
  $bucket->get_key_filename( $object, GET => $filename );

  return $filename;
}

########################################################################
sub invalidate_index {
########################################################################
  my ($self) = @_;

  # TBD
  return;
}

########################################################################
sub create_invalidation_batch {
########################################################################
  my (%args) = @_;

  local $LIST_SEPARATOR = q{};

  my @now = localtime;

  my $caller_reference = $args{CallerReference} || "@now";

  my $invalidation_batch = {
    DistributionId    => $args{DistributionId},
    InvalidationBatch => {
      CallerReference => $caller_reference,
      Paths           => {
        Items    => $args{Items},
        Quantity => scalar @{ $args{Items} },
      }
    }
  };

  return $invalidation_batch;
}

########################################################################
sub _upload_html {
########################################################################
  my ( $self, $file, $key ) = @_;

  croak sprintf '%s not found', $file
    if !-e $file;

  my $attr = { 'content-type' => 'text/html' };

  my $bucket = $self->get_bucket();

  if ( ref $file ) {
    $bucket->add_key( $key, ${$file}, $attr );
  }
  else {
    $bucket->add_key_filename( $key, $file, $attr );
  }

  return;
}

########################################################################
sub upload_index {
########################################################################
  my ( $self, $index ) = @_;

  if ( !$index ) {
    ($index) = $self->get_args();
  }

  $index //= 'index.html';

  return $self->_upload_html( $index, 'index.html' );
}

########################################################################
sub show_orepan_index {
########################################################################
  my ($self) = @_;

  my $file = $self->fetch_orepan_index;

  my $index = OrePAN2::Index->new();

  $index->load($file);

  my $listing = $index->as_string;

  return $self->send_output($listing);
}

########################################################################
sub create_docs {
########################################################################
  my ($self) = @_;

  my $distribution = basename( $self->get_distribution );

  if ( $distribution !~ /^D\/DU/xsm ) {
    $distribution = sprintf 'D/DU/DUMMY/%s', $distribution;
  }

  my ( $key_prefix, $version ) = parse_distribution_path($distribution);

  my $module_name = $key_prefix;
  $module_name =~ s/\-/::/gxsm;

  my $dpu = DarkPAN::Utils->new( base_url => $self->get_mirror );

  $dpu->fetch_package($distribution);

  my $file = $dpu->extract_module( $distribution, $module_name );

  if ( $self->get_upload ) {
    if ($file) {
      $self->upload_html(
        name    => "$key_prefix.html",
        content => $file,
        prefix  => $key_prefix,
        pod     => $TRUE,
        wrap    => $TRUE,
      );
    }
  }
  else {
    open my $fh, '>', "$key_prefix.html"
      or die "could not open $key_prefix.html for writing\n";

    print {$fh} $file;

    close $fh;
  }

  my $readme = $dpu->extract_file( sprintf '%s-%s/README.md', $key_prefix, $version );

  if ( $self->get_upload && $readme ) {
    $self->upload_html(
      name    => 'README.html',
      content => $readme,
      prefix  => $key_prefix,
      wrap    => $TRUE,
    );
  }
  else {
    open my $fh, '>', 'README.html'
      or die "could not open README.html for writing\n";

    print {$fh} $readme;

    close $fh;
  }

  return 0;
}

########################################################################
sub upload_html {
########################################################################
  my ( $self, %args ) = @_;

  my ( $content, $pod, $prefix, $name ) = @args{qw(content pod prefix name)};

  my $docs = DarkPAN::Utils::Docs->new( text => $content );

  if ($pod) {
    $docs->parse_pod;
  }
  else {
    $docs->to_html;
  }

  my $html = $docs->get_html;

  if ( $args{wrap} ) {
    $html = << "END_OF_HTML";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
 <head>
   <title>README</title>
   <link rel="stylesheet" href="/css/pod.css">
 </head>
 <body>
  $html
 </body>
</html>
END_OF_HTML
  }

  my $key = sprintf 'docs/%s/%s', $prefix, $name;

  $self->_upload_html( $html, $key );

  return;
}

########################################################################
sub look_for_object {
########################################################################
  my ( $self, $prefix, $name ) = @_;

  my $key = sprintf 'docs/%s/%s', $prefix, $name;

  return sprintf '/docs/%s/%s', $prefix, $name
    if $self->get_bucket->head_key($key);

  return;
}

########################################################################
sub create_index {
########################################################################
  my ($self) = @_;

  my $file = $self->fetch_orepan_index;

  my $repo = $self->parse_index($file);

  no strict 'refs';  ## no critic

  *{'utils::module_name'} = sub {
    my ( $self, $distribution ) = @_;

    my $module_name = basename("/$distribution");
    $module_name =~ s/-\d+[.].*$//xsm;

    return $module_name;
  };

  my $utils = bless {}, 'utils';

  my %app_plugins;
  my %plugins;
  my %readme_links;
  my %pod_links;

  foreach my $distribution ( keys %{$repo} ) {

    my ($distribution_name) = parse_distribution_path($distribution);

    my $readme = $self->look_for_object( $distribution_name, 'README.html' );

    my $pod = $self->look_for_object( $distribution_name, "${distribution_name}.html" );

    my $old_name = $distribution;
    $distribution =~ s/^.*\/([^\/]+)/$1/xsm;
    $repo->{$distribution} = delete $repo->{$old_name};

    if ($readme) {
      $readme_links{$distribution} = $readme;
    }

    if ($pod) {
      $pod_links{$distribution} = $pod;
    }

    if ( $distribution =~ /^BLM\-Startup/xsm ) {
      $app_plugins{$distribution} = delete $repo->{$distribution};
    }
    elsif ( $distribution =~ /^BLM/xsm ) {
      $plugins{$distribution} = $repo->{$distribution};
    }
  }

  my $params = {
    utils        => $utils,
    repo         => $repo,
    plugins      => \%plugins,
    app_plugins  => \%app_plugins,
    readme_links => \%readme_links,
    pod_links    => \%pod_links,
    localtime    => scalar localtime,
  };

  my $text = $self->get_template;

  my $template = Template->new();

  my $output = q{};

  $template->process( \$text, $params, \$output )
    or die $template->error();

  if ( $self->get_upload ) {
    $self->_upload_html( \$output, 'index.html' );
  }
  else {
    $self->send_output($output);
  }

  return 0;
}

########################################################################
sub send_output {
########################################################################
  my ( $self, $content ) = @_;

  my $outfile = $self->get_output;

  my $fh = eval {

    return *STDOUT
      if !$outfile;

    open my $fh, '>', $outfile;

    return $fh;
  };

  die "could not open file for output\n$EVAL_ERROR"
    if !$fh;

  print {$fh} $content;

  $outfile && close $fh;

  return 0;
}

########################################################################
sub parse_index {
########################################################################
  my ( $self, $file ) = @_;

  my $index = OrePAN2::Index->new();

  $index->load($file);

  my $listing = $index->as_string;
  $listing =~ s/^(.*)\n\n//xsm;

  my %repo;

  foreach ( split /\n/xsm, $listing ) {
    my ( $module, $version, $package ) = split /\s+/xsm;
    $repo{$package} //= [];
    push @{ $repo{$package} }, [ $module, $version ];
  }

  return \%repo;
}

########################################################################
sub download_orepan_index {
########################################################################
  my ($self) = @_;

  my $filename = eval { return $self->fetch_orepan_index(); };

  die "could not download $PACKAGE_INDEX\n$EVAL_ERROR"
    if !$filename || !-s "$filename";

  rename $filename, $PACKAGE_INDEX;

  print {*STDOUT} $PACKAGE_INDEX . "\n";

  return;
}

########################################################################
sub init {
########################################################################
  my ($self) = @_;

  $self->fetch_config;

  my $profile = $self->get_config->{AWS}->{profile};

  my $credentials = Amazon::Credentials->new( profile => $profile );

  $self->set_credentials($credentials);

  $self->fetch_template;

  return;
}

########################################################################
sub fetch_template {
########################################################################
  my ($self) = @_;

  my $template = $self->get_template;

  my $index = $self->get_config->{index} // {};

  # see if the index is set in the config file...
  if ( !$template && $index->{template} ) {
    $template = $index->{template};
  }

  my $fh = *DATA;

  my $index_template = slurp_file( $template // $fh );

  $index_template =~ s/\n\n=pod.*$/\n/xsm;

  $self->set_template($index_template);

  return;
}

########################################################################
sub extract_from_tarball {
########################################################################
  my ( $tarball, $file ) = @_;

  my $t = Archive::Tar->new;

  $t->read( $tarball, 1 )
    or croak "failed to read tarball: $tarball";

  my $prefix = basename($tarball);
  $prefix =~ s/[.]tar.*$//xsm;

  croak "file not found ($prefix/$file)"
    if !$t->contains_file("$prefix/$file");

  my $content = eval { return Load( $t->get_content("$prefix/$file") ); };

  return $content;
}

########################################################################
sub main {
########################################################################
  my $cli = OrePAN2::S3->new(
    option_specs => [
      qw(
        help|h
        config-file|c=s
        output|o=s
        profile|p=s
        template|t=s
        mirror|m=s
        distribution|d=s
        upload|u
      )
    ],
    default_options => { config_file => $DEFAULT_CONFIG, profile => 'default' },
    extra_options   => [qw(config s3 credentials template)],
    commands        => {
      'create-docs'   => \&create_docs,
      create          => \&create_index,
      show            => \&show_orepan_index,
      download        => \&download_orepan_index,
      upload          => \&upload_index,
      'dump-template' => sub {
        print {*STDOUT} shift->get_template;
        return 0;
      }
    },
  );

  return $cli->run();
}

1;

__DATA__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-15">
    <title>CPAN Repository</title>
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"
    integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo="
    crossorigin="anonymous"></script>

    <script>
    $(function() {
        $('.collapsable').hide();

        $('h2').on('click', function() {
            $(this).next().toggle();
        });
    });

    </script>
    <style>
    h2 {
      cursor: pointer;
      color: purple;
    }
    h2:hover {
      color: green;
    }
    body {
      font-family: monospace;
    }
    </style>
  </head>
  
  <body>
    <h1>CPAN Repository</h1>
    
[% FOREACH distribution = repo.keys %]
      <h2>[% distribution %]</h2>

      <ul class="collapsable" id="[% utils.module_name(distribution) %]">
[% FOREACH module IN repo.$distribution %]
        <li>[%  module.0 %]</li>
[% END %]
      </ul>
[% END %]
    
    <hr>
    <address>Generated on [% localtime %] by Template::Toolkit</address>
  </body>
</html>

=pod

=head1 NAME

 orepan2-s3

=head1 DESCRIPTION

This script is used to add distributions to your own DarkPAN
repository housed on Amazon's S3 storage. It leverages L<OrePAN2> to
create and maintain your own DarkPAN repository. You can read more
about setting up a DarkPAN on Amazon using S3 + Cloudfront
L<here|https://github.com/rlauer6/OrePAN2-S3/blob/master/README.md>.

=head1 USAGE

 orepan2-s3 Options Command

Script for maintaining a DarkPAN mirror using S3 + CloudFront

=head2 Commmands

=over 5

=item * create - Create a new F<index.html> from the mirror's manifest file.

=item * download - Download the mirror's manifest file (F<02packages.details.text.gz>).

=item * show - Print the manifest file to STDOUT or a file.

=item * upload - Upload the index.html file to the mirror's root.

=item * dump-template - Outputs the default index.html template.

=item * create-docs - parse distribution looking for a README.md and/or pod

=back

=head2 Options

 -h, --help           Display this help message
 -c, --config-file    Name of the configuration file (default: ~/.orepan2-s3.json)
 -o, --output         Name of the output file
 -p, --profile        Name of a profile inside the config file
 -t, --template       Name of a template that will be used as the index.html page
 -m, --mirror         CPAN mirror base url, example: https://cpan.openbedrock.net/orepan2
 -d, --distribution   Path to distribution tarball
 -u, --upload         Upload files after processing (for create-index, create-docs)

=head2 Configuration File

The configuration file for C<orepan2-s3> is a JSON file that can
contain multiple profiles (or none). The format should look something
like this:

  {
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
      "default" : {
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
              "InvalidationPaths" : []
          }
      }
  }

Each profile can contain up to 3 sections (AWS, CloudFront, index). If you only
have one profile you don't need place it in a 'default' section.

=over 5

=item index

This section allows you to create custom template for the DarkPAN home page.

=over 10

=item template

The name of a template file that will be parsed and uploaded as
F</index.html>. If you do not provide a template file a default
template. The default template is a L<Template::Toolkit> style
template. To see the default template use the C<dump-template> command
to the F<orepan2-index> script.

 orepan2-index dump-template

The templating process is provided with these variables:

=over 15

=item utils

A blessed reference to an object with one method (C<module_name>) that
returns a verison of the module_name suitable for use as unique id.

=item repo

A hash of key value pairs where the key is the name of a DarkPAN
distribution and value is an array or arrays. Each array is of the
form:

 [0] => Perl module name
 [1] => Module version

=item localtime

The current time and date as a string.

=back

=item files

A hash of source/destination pairs that specify additional files to upload.

Example:

 "files" { 
    "/home/rlauer/git/some-project/foo.css" : "/css/foo.css",
    "/home/rlauer/git/some-project/foo.js" : "/javascript/foo.js"
 }

=back

=item AWS

=over 10

=item profile

The IAM profile where the bucket is provisioned.

=item region

AWS region. Default: us-east-1

=item bucket

S3 bucket name

=item prefix

The prefix where the CPAN distribution files will be stored. Default: orepan2.

=back

=item CloudFront

=over 10

=item DistributionId

CloudFront distribution id

=item InvalidationPaths

An array of additional paths to invalidate when adding new distributions.

I<Note: There is no additional charge for adding additional
paths. Each invalidation batch is considered as one billing unit by
AWS. However, keep in mind you get 1000 invalidation paths for free
each month. Thereafter each path costs $0.005 per path.>

=back

=back

=head1 AUTHOR

Rob Lauer - <rlauer6@comcast.net>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
