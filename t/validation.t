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
  skip "Windows test", 1 unless $builder->is_windowsish();
  ok( $builder->alien_validate_repo( 'Windows' ), "OS string (Windows)");

}

SKIP: {
  skip "Unix test", 1 unless $builder->is_unixish();
  ok( $builder->alien_validate_repo( 'Unix' ), "OS string (Unix)");

}

done_testing;

