use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'My::Test', 
  dist_version => 0.01,
  alien_name => 'test',
  alien_helper => {
    foo => ' "bar" . "baz" ',
    exception => ' die "abcd" ',
    double => '"1";',
    argument_count1 => 'scalar @_',
  },
  alien_bin_requires => {
    'Alien::foopatcher' => 0,
  },
); 

is( $builder->alien_interpolate('%phello'), $builder->alien_exec_prefix . 'hello', 'prefix interpolation');
is( $builder->alien_interpolate('%%phello'), '%phello', 'no prefix interpolation with escape');

my $path = $builder->alien_library_destination;
is( $builder->alien_interpolate('thing other=%s'), "thing other=$path", 'share_dir interpolation');
is( $builder->alien_interpolate('thing other=%%s'), 'thing other=%s', 'no share_dir interpolation with escape');

my $perl = $builder->perl;
is( $builder->alien_interpolate('%x'), $perl, '%x is current interpreter' );
unlike( $builder->alien_interpolate('%X'), qr{\\}, 'no backslash in %X' );

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

is( $builder->alien_interpolate("|%{foo}|"), "|barbaz|", "helper" );
is( $builder->alien_interpolate("|%{foo}|%{foo}|"), "|barbaz|barbaz|", "helper x 2" );
eval { $builder->alien_interpolate("%{exception}") };
like $@, qr{abcd}, "exception gets thrown";

$builder->_alien_bin_require('Alien::foopatcher');
is( $builder->alien_interpolate("|%{patch1}|"), "|patch1 --binary|", "helper from independent Alien module");
is( $builder->alien_interpolate("|%{patch2}|"), "|patch2 --binary|", "helper from independent Alien module with code ref");

eval { $builder->alien_interpolate("%{bogus}") };
like $@, qr{no such helper: bogus}, "exception thrown with bogus helper";

is( $builder->alien_interpolate('%{double}'), "1", "MB helper overrides AB helper");

is( $builder->alien_interpolate('%{argument_count1}'), "0", "argument count is zero (string helper)");
is( $builder->alien_interpolate('%{argument_count2}'), "0", "argument count is zero (code helper)");

is( $builder->alien_interpolate('%{pkg_config}'), Alien::Base::PkgConfig->pkg_config_command, "support for %{pkg_config}");

done_testing;

package
    MyGuard;  # Hide from PAUSE

sub new     { bless { ondie => $_[1] }, $_[0] }
sub DESTROY { $_[0]{ondie}->() if ( $_[0]{ondie} ) }

package
    Alien::foopatcher;

BEGIN { $INC{'Alien/foopatcher.pm'} = __FILE__; our $VERSION = '0.01' }

sub alien_helper {
    return {
      patch1 => 'join " ", qw(patch1 --binary)',
      patch2 => sub { 'patch2 --binary' },
      double => sub { 2 },
      argument_count2 => sub { scalar @_ },
    },
}
