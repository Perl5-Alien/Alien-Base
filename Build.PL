use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Alien::Base',
  dist_abstract => 'A base class for Alien:: modules',
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  license  => 'perl',
  requires => {
    'perl'             => '5.8.1',
    'parent'           => 0,
    'Capture::Tiny'    => 0,
    'File::chdir'      => 0,
    'Sort::Versions'   => 0,
    'List::MoreUtils'  => 0,
    'Perl::OSType'     => 0,
    'URI'              => 0,
    'File::ShareDir'   => 0,
    'Archive::Extract' => 0,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/Alien-Base",
    },
    no_index => {
      file      => [ 'README.pod' ],
      directory => [ 'examples', 't/system_installed' ],
    },
  },
);

$builder->create_build_script;
