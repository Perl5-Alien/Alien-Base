use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;
use File::Spec::Functions 'rel2abs';

my $builder = {
  properties => { alien_share_folder => rel2abs 't' },
};

bless $builder, 'Alien::Base::ModuleBuild';

is( $builder->alien_interpolate('%phello'), $builder->alien_exec_prefix . 'hello', 'prefix interpolation');
is( $builder->alien_interpolate('%%phello'), '%phello', 'no prefix interpolation with escape');

my $path = rel2abs "t";
is( $builder->alien_interpolate('thing other=%s'), "thing other=$path", 'share_dir interpolation');
is( $builder->alien_interpolate('thing other=%%s'), 'thing other=%s', 'no share_dir interpolation with escape');

done_testing;

