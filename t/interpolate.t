use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'My::Test', 
  dist_version => 0.01,
  alien_name => 'test',
); 

is( $builder->alien_interpolate('%phello'), $builder->alien_exec_prefix . 'hello', 'prefix interpolation');
is( $builder->alien_interpolate('%%phello'), '%phello', 'no prefix interpolation with escape');

my $path = $builder->alien_library_destination;
is( $builder->alien_interpolate('thing other=%s'), "thing other=$path", 'share_dir interpolation');
is( $builder->alien_interpolate('thing other=%%s'), 'thing other=%s', 'no share_dir interpolation with escape');

my $perl = $builder->perl;
is( $builder->alien_interpolate('%x'), $perl, '%x is current interpreter' );

# Prior to loading the version information
{
  my @warn             = ();
  local $SIG{__WARN__} = sub { push @warn, @_ };

  is  ( $builder->alien_interpolate('version=%v'), 'version=%v', 'version prior to setting it' );
  isnt( join( "\n", @warn ),                       '',           'version warning prior to setting it' );
}

# After loading the version information
{
  my @warn             = ();
  local $SIG{__WARN__} = sub { push @warn, @_ };

  $builder->config_data( 'version', '1.2.3' );
  is( $builder->alien_interpolate('version=%v'), "version=1.2.3", 'version after setting it' );
  is( join( "\n", @warn ),                       '',              'version warning after setting it' );
}

done_testing;

