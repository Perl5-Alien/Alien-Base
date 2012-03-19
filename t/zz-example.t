use strict;
use warnings;

use Test::More;

use File::chdir;

local $CWD;
push @CWD, qw/examples Alien-DontPanic/;

my $builder = do 'Build.PL' or warn $@;

unless( $builder->have_c_compiler ) {
  plan skip_all => "Need C compiler";
}

isa_ok( $builder, 'Module::Build' );
isa_ok( $builder, 'Alien::Base::ModuleBuild' );

$builder->depends_on('alien');
ok( -d '_install', "ACTION_alien creates _install (share) directory" );
ok( -d '_alien',   "ACTION_alien creates _alien (build) directory" );
{
  local $CWD = '_install';
  {
    local $CWD = 'lib';
    ok( -e 'libdontpanic.so', "ACTION_alien installs lib" );
  }
  {
    local $CWD = 'include';
    ok( -e 'libdontpanic.h', "ACTION_alien installs header" );
  }
}

my $pc_objects = $builder->config_data('pkgconfig');
my $dontpanic_pc = $pc_objects->{dontpanic};
isa_ok( $dontpanic_pc, 'Alien::Base::PkgConfig', "Generate pkgconfig" );

$builder->depends_on('build');
{ # prepare @INC for Ford::Prefect
  local $CWD = $builder->blib;
  push @CWD, 'lib';
  push @INC, $CWD;
}

{ # Ford::Prefect relies on Alien::DontPanic
  local $CWD;
  pop @CWD; # cd ..
  push @CWD, 'Ford-Prefect';

  ok( -e 'Build.PL', "Ford::Prefect's Build.PL found" );
  my $ford_builder = do 'Build.PL' or warn $@;
  isa_ok( $ford_builder, 'Module::Build' );

  $ford_builder->depends_on('build');

  {
    local $CWD;
    push @CWD, qw/blib lib/;
    push @INC, $CWD;
  }

  {
    local $CWD;
    push @CWD, qw/blib arch/;
    push @INC, $CWD;
  }

  my $answer = eval { require Ford::Prefect; Ford::Prefect::answer() };
  warn $@ if $@;
  is( $answer, 42, "Ford::Prefect knows the answer" );

  $ford_builder->depends_on('realclean');
}

$builder->depends_on('realclean');
ok( ! -e 'Build'   , "realclean removes Build script" );
ok( ! -d '_install', "realclean removes _install (share) directory" );
ok( ! -d '_alien'  , "realclean removes _alien (build) directory" );

done_testing;
