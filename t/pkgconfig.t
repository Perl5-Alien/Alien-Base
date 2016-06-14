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
my $pcfiledir = delete $pc->{vars}{pcfiledir};
ok( -d $pcfiledir, 'pcfiledir is a directory' );
ok( -e File::Spec->catfile($pcfiledir, 'test.pc'), 'pcfiledir contains test.pc' );

is_deeply( 
  $pc->{vars}, 
  {
    'INTERNAL_VARIABLE' => '-lotherlib',
    'prefix' => '/home/test/path',
  },
  "read vars"
);

is_deeply(
  $pc->{keywords},
  {
    'Version' => '1.01',
    'Libs' => '-L/home/test/path/lib -lsomelib ${INTERNAL_VARIABLE} -lm -lm',
    'Cflags' => '-Dfoo=bar -I/home/test/path/deeper/include',
    'Requires' => 'lib1 >= 1.0.0 lib2 >= 1.2.3',
    'Description' => 'My TEST Library',
    'Name' => 'TEST',
  },
  "read keywords"
);

is( $pc->{package}, 'test', "understands package name from file path" );

# vars getter/setter
is( $pc->var('prefix'), '/home/test/path', "var getter" );
is( $pc->var(deeper => '/home/test/path/deeper'), '/home/test/path/deeper', "var setter" );

# abstract vars
$pc->make_abstract('prefix');

is( $pc->{vars}{deeper}, '${prefix}/deeper', "abstract vars in terms of each other" );
is( (split qr/\s+/, $pc->{keywords}{Libs})[0], '-L${prefix}/lib', "abstract simple" );

$pc->make_abstract('deeper');
is( $pc->{keywords}{Cflags}, '-Dfoo=bar -I${deeper}/include', "abstract abstract 'nested'" );

# interpolate vars into keywords
is( $pc->keyword('Version'), '1.01', "Simple keyword getter" );
is( (split qr/\s+/, $pc->keyword('Libs'))[0], '-L/home/test/path/lib', "single interpolation keyword" );
is( $pc->keyword('Cflags'), '-Dfoo=bar -I/home/test/path/deeper/include', "multiple interpolation keyword" );

# interpolate with overrides
is( 
  $pc->keyword( 'Cflags', {prefix => '/some/other/path'}), 
  '-Dfoo=bar -I/some/other/path/deeper/include', 
  "multiple interpolation keyword with override"
);

done_testing;

