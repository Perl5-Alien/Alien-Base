use strict;
use warnings;

use Test::More;
use Alien::Base::ModuleBuild;
use File::chdir;

my $expected = { 
  lib      => [ 'lib' ], 
  inc      => [ 'include' ],
  so_files => [ 'mylib' ],
};

my $dir = do {
  local $CWD;
  push @CWD, qw/t find_lib/;
  $CWD;
};

my $builder = Alien::Base::ModuleBuild->new( 
  module_name => 'My::Test', 
  dist_version => 0.01,
  alien_name => 'test',
);

$builder->config( so => 'so' );

{  # Find from file structure
  local $expected->{so_files} = [qw/mylib otherlib/];
  my $paths = $builder->alien_find_lib_paths($dir);
  is_deeply( $paths, $expected, "found paths from extensions only" ); 

  my $pc = $builder->alien_generate_manual_pkgconfig($dir);
  isa_ok($pc, 'Alien::Base::PkgConfig');

  my $libs = $pc->keyword('Libs');

  like( $libs, qr/-lmylib/, "->keyword('Libs') returns mylib" );

  my ($L) = $libs =~ /-L(\S*)/g;
  ok( -d $L,  "->keyword('Libs') finds mylib directory");
  opendir(my $dh, $L);
  my @files = grep { /mylib/ } readdir $dh;
  ok( @files, "->keyword('Libs') finds mylib" );
}

{  # Find using alien_provides_libs
  $builder->alien_provides_libs('-lmylib');
  my $paths = $builder->alien_find_lib_paths($dir);
  is_deeply( $paths, $expected, "found paths from provides" ); 

  my $pc = $builder->alien_generate_manual_pkgconfig($dir);
  isa_ok($pc, 'Alien::Base::PkgConfig');

  my $libs = $pc->keyword('Libs');

  like( $libs, qr/-lmylib/, "->keyword('Libs') returns mylib" );

  my ($L) = $libs =~ /-L(\S*)/g;
  ok( -d $L,  "->keyword('Libs') finds mylib directory");
  opendir(my $dh, $L);
  my @files = grep { /mylib/ } readdir $dh;
  ok( @files, "->keyword('Libs') finds mylib" );
}

done_testing;

