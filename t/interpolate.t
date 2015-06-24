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
#
# The guard used below is needed so that the configuration data
# modified as part of the test is rolled back at the end of the test.
#
{
  my @warn             = ();
  local $SIG{__WARN__} = sub { push @warn, @_ };

  my $current_version = $builder->config_data( 'alien_version' ) ;
  my $guard = MyGuard->new(
      sub {
	  my $self = shift;
	  $builder->config_data( 'alien_version', $current_version );
      },
      );

  my $test_version = time;
  $builder->config_data( 'alien_version', $test_version );

  is( $builder->alien_interpolate('version=%v'), "version=$test_version", 'version after setting it' );
  is( join( "\n", @warn ),                       '',                      'version warning after setting it' );
}

is $builder->alien_interpolate('| %{ "foo" . "bar" } |'), '| foobar |', 'interpolation of arbitrary perl';
is $builder->alien_interpolate('| %{ join ",", map { $_ - 1 } 2..11 } |'), '| 1,2,3,4,5,6,7,8,9,10 |', 'interpolation of arbitrary perl with nested brackets';

done_testing;

package
    MyGuard;  # Hide from PAUSE

sub new     { bless { ondie => $_[1] }, $_[0] }
sub DESTROY { $_[0]{ondie}->() if ( $_[0]{ondie} ) }
