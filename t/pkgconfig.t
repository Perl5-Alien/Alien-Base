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
    'prefix' => '/home/test/path',
    'deeper' => '/home/test/path/deeper',
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
      '-I/home/test/path/deeper/include'
    ],
    'Description' => 'My TEST Library',
    'Name' => 'TEST'
  },
  "read keywords"
);

is( $pc->{package}, 'test', "understands package name from file path" );

# abstract vars
$pc->make_abstract;

is( $pc->{vars}{deeper}, '${prefix}/deeper', "abstract vars in terms of each other" );
is( $pc->{keywords}{Libs}[0], '-L${prefix}/lib', "abstract simple" );
is( $pc->{keywords}{Cflags}[0], '-I${deeper}/include', "abstract abstract 'nested'" );

# interpolate vars

done_testing;

