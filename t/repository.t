use strict;
use warnings;

#use File::chdir;
#use File::Temp ();

use Test::More;
use_ok( 'Alien::Base::ModuleBuild::Repository' );

END{ done_testing() }

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
$repo->{src}{pattern} = $pattern;
@filenames = grep { $_ =~ $pattern } @filenames;

{
  my @files = $repo->probe();

  is( scalar @files, scalar @filenames, 'with pattern, probe returns an object for each matching file');
  isa_ok( $files[0], 'Alien::Base::ModuleBuild::File' );
  ok( ! defined $files[0]->version, 'without capture, no version information is available');
}

__END__

my $tempdir = File::Temp->newdir();
ok( -d "$tempdir", 'Temporary folder exists');
my $file = $files->[0];
{
  local $CWD = "$tempdir";
  $repo->get_file($file);
  ok( -e $file, 'Downloaded file exists');
}

#reset
$repo->{src}{files} = [];

$pattern = qr/^gsl-([\d\.])+\.tar\.gz$/;
$repo->{src}{pattern} = $pattern;
$files = $repo->probe();
is( ref $files, 'HASH', 'with capturing pattern, probe returns hashref');

done_testing;

