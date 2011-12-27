use strict;
use warnings;

use Test::More;
use_ok('Alien::Base');

my $skip;
system( 'pkg-config --version' );
if ( $? ) {
  $skip = "Cannot use pkg-config: $?";
}

SKIP: {
  skip $skip, 2 if $skip;

  my @installed = map { /^(\S+)/ ? $1 : () } `pkg-config --list-all`;
  my $lib = $installed[0];

  my $builder_ok = bless { alien_name => $lib }, 'Alien::Base';
  my $builder_bad = bless { alien_name => 'siughspidghsp' }, 'Alien::Base';

  is( !! $builder_ok->alien_check_installed_version, 1, "Found installed library $lib" );
  is( $builder_bad->alien_check_installed_version, 0, 'Returns 0 if not found' );

}

done_testing;

