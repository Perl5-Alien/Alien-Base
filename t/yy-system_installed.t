use strict;
use warnings;

use File::chdir;
use List::Util qw/shuffle/;

use Test::More;
use Alien::Base::ModuleBuild;

# Since this is not a complete distribution, it complains about missing files/folders
local $SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /Can't (?:stat)|(?:find)/ };

local $CWD;
push @CWD, qw/t system_installed/;

my $skip;
system( 'pkg-config --version' );
if ( $? ) {
  plan skip_all => "Cannot use pkg-config: $?";
}

my @installed = shuffle map { /^(\S+)/ ? $1 : () } `pkg-config --list-all`;

my $lib = shift @installed;

chomp( my $cflags = `pkg-config --cflags $lib` );
chomp( my $libs = `pkg-config --libs $lib` );

$cflags =~ s/\s*$//;
$libs   =~ s/\s*$//;

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

