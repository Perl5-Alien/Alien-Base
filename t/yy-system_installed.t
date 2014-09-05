use strict;
use warnings;

use File::chdir;
use List::Util qw/shuffle/;

BEGIN { $ENV{ALIEN_FORCE} = 0 }

use Test::More;
use Alien::Base::ModuleBuild;
use Alien::Base::PkgConfig;

# Since this is not a complete distribution, it complains about missing files/folders
local $SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /Can't (?:stat)|(?:find)/ };

$ENV{ALIEN_BLIB} = 0;

local $CWD;
push @CWD, qw/t system_installed/;

my $pkg_config = Alien::Base::PkgConfig->pkg_config_command;

my $skip;
system( "$pkg_config --version" );
if ( $? ) {
  plan skip_all => "Cannot use pkg-config: $?";
}

my @installed = shuffle map { /^(\S+)/ ? $1 : () } `$pkg_config --list-all`;
plan skip_all => "Could not find any library for testing" unless @installed;

my ($lib, $cflags, $libs);

my $i = 1;

while (1) {

  $lib = shift @installed;

  chomp( $cflags = `$pkg_config --cflags $lib` );
  chomp( $libs = `$pkg_config --libs $lib` );

  $cflags =~ s/\s*$//;
  $libs   =~ s/\s*$//;

  if ($lib and $cflags and $libs) {
    last;
  } 

  if ($i++ == 3) {
    plan skip_all => "Could not find a suitable library for testing";
    last;
  }

  $lib    = undef;
  $cflags = undef;
  $libs   = undef;
}

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'MyTest', 
  dist_version => 0.01,
  alien_name => $lib,
  share_dir => 't',
); 

$builder->depends_on('build');

{
  local $CWD;
  push @CWD, qw/blib lib/;

  require MyTest;
  my $alien = MyTest->new;

  isa_ok($alien, 'MyTest');
  isa_ok($alien, 'Alien::Base');

  is($alien->cflags, $cflags, "get cflags from system-installed library");
  is($alien->libs  , $libs  , "get libs from system-installed library"  );
}

$builder->depends_on('realclean');

done_testing;

