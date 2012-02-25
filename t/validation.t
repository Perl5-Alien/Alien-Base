use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild');

my $builder = bless {}, 'Alien::Base::ModuleBuild';

ok( $builder->alien_validate_repo( {platform => undef} ), "undef validates to true");

SKIP: {
  skip "Windows test", 2 unless $builder->is_windowsish();
  ok( $builder->alien_validate_repo( {platform => 'Windows'} ), "OS string (Windows)");
  ok( ! $builder->alien_validate_repo( {platform => 'Unix'} ), "OS string (Unix on Windows) is false");
}

SKIP: {
  skip "Unix test", 2 unless $builder->is_unixish();
  ok( $builder->alien_validate_repo( {platform => 'Unix'} ), "OS string (Unix)");
  ok( ! $builder->alien_validate_repo( {platform => 'Windows'} ), "OS string (Windows on Unix) is false");
}

done_testing;

