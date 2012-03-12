use strict;
use warnings;

use lib '../../lib';

use utf8;
use Alien::Base::ModuleBuild;

my $builder = Alien::Base::ModuleBuild->new(
  module_name => 'Alien::Nettle',
  dist_abstract => 'Build and install the Nettle cryptographic library',
  license => 'perl',
  configure_requires => {
    'Alien::Base' => 0,
  },
  requires => {
    'perl' => '5.8.1',
    'Alien::Base' => 0,
  },
  dist_author => 'Richard Simões <rsimoes AT cpan DOT org>',
  alien_name => 'nettle',
  alien_repository => {
    protocol => 'ftp',
    host     => 'ftp.lysator.liu.se',
    location => '/pub/security/lsh',
    pattern  => qr/^nettle-([\d\.]+)\.tar\.gz$/,
  },
  alien_build_commands => [
    '%pconfigure --prefix=%s --enable-shared', 
    'make',
    'make install'
  ],
);
$builder->create_build_script;


