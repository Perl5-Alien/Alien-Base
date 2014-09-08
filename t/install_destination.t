use strict;
use warnings;

use Test::More;

use Alien::Base::ModuleBuild;
use File::chdir;
use File::Temp ();
use File::Spec;

my $dir = File::Temp->newdir;
local $CWD = "$dir";

my %basic = (
  module_name  => 'My::Test',
  dist_version => '0.01',
  dist_author  => 'Joel Berger',
);

my $builder = Alien::Base::ModuleBuild->new( %basic );
my $path = $builder->alien_library_destination;

# this is not good enough, I really wish I could introspect File::ShareDir, then again, I wouldn't need this test!
my $path_to_share = File::Spec->catdir( qw/auto share dist My-Test/ );
$path_to_share =~ s{\\}{/}g if $^O eq 'MSWin32';
like $path, qr/\Q$path_to_share\E/, 'path looks good';


done_testing;

