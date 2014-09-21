use strict;
use warnings;

use Module::Build;

my %build_args = (
  module_name => 'Alien::Base',
  dist_abstract => 'A base class for Alien:: modules',
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  license  => 'perl',
  configure_requires => {
    'Module::Build' => 0.36,
  },
  requires => {
    'perl'             => '5.8.1',
    'parent'           => 0,
    'Module::Build'    => 0.36,
    'Capture::Tiny'    => 0.17,
    'File::chdir'      => 0.1005,
    'Sort::Versions'   => 0,
    'List::MoreUtils'  => 0,
    'Perl::OSType'     => 0,
    'URI'              => 0,
    'File::ShareDir'   => 0,
    'Archive::Extract' => 0,
    'HTTP::Tiny'       => 0,
    'Text::ParseWords' => '3.26',
  },
  test_requires => {
    'Test::More'       => 0.94,
    'Cwd'              => 0,
    'FindBin'          => 0,
    'File::Spec'       => 0,
    'File::Temp'       => 0,
  },
  recommends => {
    'HTML::LinkExtor' => 0,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/Perl5-Alien/Alien-Base",
      bugtracker => "http://github.com/Perl5-Alien/Alien-Base/issues",
      x_MailingList => 'https://groups.google.com/forum/#!forum/perl5-alien',
    },
    no_index => {
      file      => [ 'README.pod' ],
      directory => [ 'examples', 't' ],
    },
  },
);

unless (`pkg-config --version` && $? == 0) {
  $build_args{'requires'}->{'PkgConfig'} = '0.07520';
}

my $builder = Module::Build->new(%build_args);
$builder->add_to_cleanup( '_Inline' );
$builder->create_build_script;
