use strict;
use warnings;

use File::Spec;

use Test::More;

use_ok('Alien::Base::PkgConfig');

my $file = File::Spec->catfile( qw/t pkgconfig test.pc/ );
ok( -e $file, "Test file found" );

my $pc = Alien::Base::PkgConfig->new($file);
isa_ok( $pc, 'Alien::Base::PkgConfig' );

# read tests
is_deeply( 
  $pc->{vars}, 
  {
    'INTERNAL_VARIABLE' => '-lotherlib',
    'prefix' => '/home/test/path'
  },
  "read vars"
);

is_deeply(
  $pc->{keywords},
  {
    'Version' => '1.01',
    'Libs' => [
      '-L/home/test/path/lib',
      '-lsomelib',
      '${INTERNAL_VARIABLE}',
      '-lm',
      '-lm'
    ],
    'Cflags' => [
      '-I/home/test/path/include'
    ],
    'Description' => 'My TEST Library',
    'Name' => 'TEST'
  },
  "read keywords"
);

is( $pc->{package}, 'test', "understands package name from file path" );

# abstract vars

# interpolate vars

done_testing;

