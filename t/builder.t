use strict;
use warnings;

use Test::More;

use Alien::Base::ModuleBuild;
use File::chdir;
use File::Temp ();
use File::Path qw( rmtree );

my $dir = File::Temp->newdir;
local $CWD = "$dir";

my %basic = (
  module_name  => 'My::Test',
  dist_version => '0.01',
  dist_author  => 'Joel Berger',
);

sub builder { return Alien::Base::ModuleBuild->new( %basic, @_ ) }

###########################
#  Temporary Directories  #
###########################

subtest 'default temp and share' => sub {
  rmtree [qw/_alien _share/], 0, 1;

  my $builder = builder;

  # test the builder function
  isa_ok($builder, 'Alien::Base::ModuleBuild');
  isa_ok($builder, 'Module::Build');

  $builder->alien_init_temp_dir;
  ok( -d '_alien', "Creates _alien dir");
  ok( -d '_share', "Creates _share dir");

  $builder->depends_on('clean');
  ok( ! -d '_alien', "Removes _alien dir");
  ok( ! -d '_share', "Removes _share dir");

  rmtree [qw/_alien _share/], 0, 1;
};

subtest 'override temp and share' => sub {
  rmtree [qw/_test_temp _test_share/], 0, 1;

  my $builder = builder(
    alien_temp_dir => '_test_temp',
    alien_share_dir => '_test_share',
  );

  $builder->alien_init_temp_dir;
  ok( -d '_test_temp', "Creates _test_temp dir");
  ok( -d '_test_share', "Creates _test_temp dir");

  $builder->depends_on('clean');
  ok( ! -d '_test_temp', "Removes _test_temp dir");
  ok( ! -d '_test_share', "Removes _test_share dir");

  rmtree [qw/_test_temp _test_share/], 0, 1;
};

done_testing;

