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

done_testing;

