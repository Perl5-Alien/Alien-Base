use strict;
use warnings;

use Test::More;
use_ok( 'Alien::Base::ModuleBuild::Repository' );

my $repo = Alien::Base::ModuleBuild::Repository->new({ 
  protocol => 'test',
  host => 'ftp.gnu.org',
  folder => '/gnu/gsl',
});

my @filenames = $repo->list_files;

{
  my @files = $repo->probe();

  is( scalar @files, scalar @filenames, 'without pattern, probe returns an object for each file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
}

my $pattern = qr/^gsl-[\d\.]+\.tar\.gz$/;
my $repo_pattern = $repo->new( pattern => $pattern );
@filenames = grep { $_ =~ $pattern } @filenames;

{
  my @files = $repo_pattern->probe();

  is( scalar @files, scalar @filenames, 'with pattern, probe returns an object for each matching file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  ok( ! defined $files[0]->version, 'without capture, no version information is available');
}

$pattern = qr/^gsl-([\d\.])+\.tar\.gz$/;
my $repo_pattern_capture = $repo->new( pattern => $pattern );

{
  my @files = $repo_pattern_capture->probe();

  is( scalar @files, scalar @filenames, 'with pattern, probe returns an object for each matching file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  ok( defined $files[0]->version, 'with capture, version information is available');
}

done_testing;

