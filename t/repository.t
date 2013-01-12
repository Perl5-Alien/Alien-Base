use strict;
use warnings;

use Test::More;

use File::chdir;
local $CWD = 't';

require RepositoryTest;

my $default = { 
  protocol => 'test',
  host     => 'ftp.gnu.org',
  location => '/gnu/gsl',
};

{
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @filenames = $repo->list_files;

  my @files = $repo->probe();

  is( scalar @files, scalar @filenames, 'without pattern, probe returns an object for each file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
}

{
  my $pattern = qr/^gsl-[\d\.]+\.tar\.gz$/;
  local $default->{pattern} = $pattern;
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @filenames = grep { $_ =~ $pattern } $repo->list_files;

  my @files = $repo->probe();

  is( scalar @files, scalar @filenames, 'with pattern, probe returns an object for each matching file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  ok( ! defined $files[0]->version, 'without capture, no version information is available');
}

{
  my $pattern = qr/^gsl-([\d\.]+)\.tar\.gz$/;
  local $default->{pattern} = $pattern;
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @filenames = grep { $_ =~ $pattern } $repo->list_files;

  my @files = $repo->probe();

  is( scalar @files, scalar @filenames, 'with pattern, probe returns an object for each matching file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  ok( defined $files[0]->version, 'with capture, version information is available');
}

{
  my $filename = 'gsl-1.9.tar.gz.sig';
  local $default->{exact_filename} = $filename;
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @files = $repo->probe();

  is( scalar @files, 1, 'with exact filename, probe returns one object');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  is( $files[0]->{filename}, $filename, 'the name of the object is the given filename');
  ok( ! defined $files[0]->version, 'without exact version, no version information is available');
}

{
  my $filename = 'gsl-1.9.tar.gz.sig';
  local $default->{exact_filename} = $filename;
  local $default->{exact_version} = '1.9';
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @files = $repo->probe();

  is( scalar @files, 1, 'with exact filename, probe returns one object');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  is( $files[0]->{filename}, $filename, 'the name of the object is the given filename');
  is( $files[0]->version, '1.9', 'with exact version, the version of the object if the given version');
}

done_testing;

