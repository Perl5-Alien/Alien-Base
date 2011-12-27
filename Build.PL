use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'Alien::Base',
  dist_abstract => 'A base class for Alien:: modules',
  license => 'perl',
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  license  => 'perl',
  requires => {
    'perl' => '5.8.1',
    'parent' => 0,
    'Capture::Tiny' => 0,
    'Sort::Versions' => 0,
  },
);

$builder->create_build_script;
