use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;

my $skip;
system( 'pkg-config --version' );
if ( $? ) {
  plan skip_all => "Cannot use pkg-config: $?";
}

my @installed = map { /^(\S+)/ ? $1 : () } `pkg-config --list-all`;
my $lib = $installed[0];

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'My::Test', 
  dist_version => 0.01,
  alien_name => $lib,
  share_dir => 't',
); 

ok(1);

done_testing;

