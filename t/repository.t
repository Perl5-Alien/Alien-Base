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
  my $sha1 = '17f8ce6a621da79d8343a934100dfd4278b2a5e9';
  local $default->{sha1} = $sha1;
  my $sha256 = 'eb154b23cc82c5c0ae0a7fb5f0b80261e88283227a8bdd830eea29bade534c58';
  local $default->{sha256} = $sha256;
  my $repo = Alien::Base::ModuleBuild::Repository::Test->new($default);

  my @files = $repo->probe();

  is( scalar @files, 1, 'with exact filename, probe returns one object');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  is( $files[0]->{filename}, $filename, 'the name of the object is the given filename');
  is( $files[0]->version, '1.9', 'with exact version, the version of the object if the given version');
  if (eval 'require Digest::SHA') {
      is( $files[0]->{sha1}, $sha1, 'the SHA-1 hash of the given filename');
      is( $files[0]->{sha256}, $sha256, 'the SHA-256 hash of the given filename');
  }
}

subtest 'exact_filename trailing slash' => sub {

  my $repo = Alien::Base::ModuleBuild::Repository->new(
    protocol       => 'https',
    host           => 'github.com',
    location       => 'hunspell/hunspell/archive',
    exact_filename => 'v1.3.4.tar.gz',
  );
  is $repo->location, 'hunspell/hunspell/archive/', 'exact filename implies trailing /';

  $repo = Alien::Base::ModuleBuild::Repository->new(
    protocol       => 'https',
    host           => 'github.com',
    location       => 'hunspell/hunspell/archive/',
    exact_filename => 'v1.3.4.tar.gz',
  );
  is $repo->location, 'hunspell/hunspell/archive/', 'exact filename with trailing slash already there';

  $repo = Alien::Base::ModuleBuild::Repository->new(
    protocol       => 'https',
    host           => 'github.com',
    location       => 'hunspell/hunspell/archive',
    pattern        => '^v([0-9\.]+).tar.gz$',
  );
  is $repo->location, 'hunspell/hunspell/archive', 'no exact filename does not imply trailing /';

};

done_testing;

