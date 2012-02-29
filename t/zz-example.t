use strict;
use warnings;

use Test::More;

use File::chdir;

local $CWD;
push @CWD, qw/examples Alien-DontPanic/;

my $builder = do 'Build.PL';
isa_ok( $builder, 'Module::Build' );
isa_ok( $builder, 'Alien::Base::ModuleBuild' );

$builder->dispatch('realclean');

ok( ! -e 'Build', "realclean removes Build script" );

done_testing;
