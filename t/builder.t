use strict;
use warnings;

use Test::More;

use Alien::Base::ModuleBuild;
use File::chdir;
use File::Temp ();

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

{
  unlink qw/_alien _install/;

  my $builder = builder;

  # test the builder function
  isa_ok($builder, 'Alien::Base::ModuleBuild');
  isa_ok($builder, 'Module::Build');

  $builder->alien_init_temp_dir;
  ok( -d '_alien', "Creates _alien dir");
  ok( -d '_install', "Creates _install dir");

  $builder->depends_on('clean');
  ok( ! -d '_alien', "Removes _alien dir");
  ok( ! -d '_install', "Removes _install dir");

  unlink qw/_alien _install/;
}

{
  mkdir '_install';

  my $builder = builder;

  $builder->alien_init_temp_dir;
  ok( -d '_alien', "Creates _alien dir");
  ok( -d '_install', "Creates _install dir");

  $builder->depends_on('clean');
  ok( ! -d '_alien', "Removes _alien dir");
  ok( -d '_install', "Clean does not remove _install dir if it existed");

  unlink qw/_alien _install/;
}

{
  unlink qw/_test_temp _test_share/;

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

  unlink qw/_test_temp _test_share/;
}

done_testing;

