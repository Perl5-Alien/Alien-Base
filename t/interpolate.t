use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;
use File::Spec::Functions 'rel2abs';

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'My::Test', 
  dist_version => 0.01,
  alien_name => 'test',
); 

is( $builder->alien_interpolate('%phello'), $builder->alien_exec_prefix . 'hello', 'prefix interpolation');
is( $builder->alien_interpolate('%%phello'), '%phello', 'no prefix interpolation with escape');

my $path = rel2abs "_install";
is( $builder->alien_interpolate('thing other=%s'), "thing other=$path", 'share_dir interpolation');
is( $builder->alien_interpolate('thing other=%%s'), 'thing other=%s', 'no share_dir interpolation with escape');

done_testing;

