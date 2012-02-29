use strict;
use warnings;

use lib '../../lib';

use Alien::Base::ModuleBuild;

my $builder = Alien::Base::ModuleBuild->new(
  module_name => 'Alien::DontPanic',
  dist_abstract => 'Test Module for Alien::Base',
  license => 'perl',
  configure_requires => {
    'Alien::Base' => 0,
  },
  requires => {
    'perl' => '5.8.1',
    'Alien::Base' => 0,
  },
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  alien_name => 'dontpanic',
  alien_repository => {
    protocol => 'local',
    location => 'inc',
    pattern  => qr/^dontpanic-([\d\.]+)\.tar\.gz$/,
  },
  alien_build_commands => [
    'perl make.pl --prefix=%s configure', 
    'perl make.pl',
    'perl make.pl install'
  ],
);
$builder->create_build_script;

# zz-example.t "do loads" this file, so hand it something:
no warnings 'void';
$builder;


