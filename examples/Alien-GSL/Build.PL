use strict;
use warnings;

use Alien::Base::ModuleBuild;

my $builder = Alien::Base::ModuleBuild->new(
  module_name => 'Alien::GSL',
  dist_abstract => 'Easy installation of the GNU Scientific Library',
  license => 'perl',
  configure_requires => {
    'Alien::Base' => 0,
  },
  requires => {
    'perl' => '5.8.1',
    'Alien::Base' => 0,
  },
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  alien_name => 'gsl',
  alien_repository => {
    protocol => 'ftp',
    host  => 'ftp.gnu.org',
    folder  => '/gnu/gsl',
    src => {
      pattern => qr/^gsl-([\d\.])+\.tar\.gz$/,
    },
  },
);
$builder->create_build_script;


