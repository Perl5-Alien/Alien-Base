use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild');

my $builder = Alien::Base::ModuleBuild->new(
  module_name  => 'My::Test::Module',
  dist_version => '1.234.567',
);

ok( $builder->alien_validate_repo( {platform => undef} ), "undef validates to true");

SKIP: {
  skip "Windows test", 2 unless $builder->is_windowsish();
  ok( $builder->alien_validate_repo( {platform => 'Windows'} ), "platform Windows on Windows");
  ok( ! $builder->alien_validate_repo( {platform => 'Unix'} ), "platform Unix on Windows is false");
}

SKIP: {
  skip "Unix test", 2 unless $builder->is_unixish();
  ok( $builder->alien_validate_repo( {platform => 'Unix'} ), "platform Unix on Unix");
  ok( ! $builder->alien_validate_repo( {platform => 'Windows'} ), "platform Windows on Unix is false");
}

SKIP: {
  skip "Needs c compiler", 1 unless $builder->have_c_compiler();
  ok( $builder->alien_validate_repo( {platform => 'src'} ), "platform src");
}

done_testing;

