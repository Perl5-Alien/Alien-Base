use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild');

my $builder = bless {}, 'Alien::Base::ModuleBuild';

ok( $builder->alien_validate_repo( undef ), "undef validates to true");
ok( $builder->alien_validate_repo( sub { 1 } ), "Simple closure");
ok( $builder->alien_validate_repo( 
  sub { my $builder = shift; $builder->isa('Alien::Base::ModuleBuild') } 
), "Closure with reference to builder");

SKIP: {
  skip "Windows test", 2 unless $builder->is_windowsish();
  ok( $builder->alien_validate_repo( 'Windows' ), "OS string (Windows)");
  ok( ! $builder->alien_validate_repo( 'Unix' ), "OS string (Unix on Windows) is false");
}

SKIP: {
  skip "Unix test", 2 unless $builder->is_unixish();
  ok( $builder->alien_validate_repo( 'Unix' ), "OS string (Unix)");
  ok( ! $builder->alien_validate_repo( 'Windows' ), "OS string (Windows on Unix) is false");
}

done_testing;

