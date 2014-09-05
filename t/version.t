use strict;
use warnings;

use Test::More;
use Alien::Base::PkgConfig;
use_ok('Alien::Base::ModuleBuild');

my $pkg_config = Alien::Base::PkgConfig->pkg_config_command;

my $skip;
system( "$pkg_config --version" );
if ( $? ) {
  $skip = "Cannot use pkg-config: $?";
}

SKIP: {
  skip $skip, 2 if $skip;

  my @installed = map { /^(\S+)/ ? $1 : () } `$pkg_config --list-all`;
  skip "pkg-config returned no packages", 2 unless @installed;
  my $lib = $installed[0];

  my ($builder_ok, $builder_bad) = map { 
    Alien::Base::ModuleBuild->new( 
      module_name => 'My::Test', 
      dist_version => 0.01,
      alien_name => $_,
      share_dir => 't',
    ); 
  }
  ($lib, 'siughspidghsp');

  is( !! $builder_ok->alien_check_installed_version, 1, "Found installed library $lib" );
  is( $builder_bad->alien_check_installed_version, 0, 'Returns 0 if not found' );

}

done_testing;

