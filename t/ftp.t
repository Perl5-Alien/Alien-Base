use strict;
use warnings;

use File::chdir;
use File::Temp ();

use Test::More;
use_ok( 'Alien::Base::ModuleBuild::Repository' );

my $repo = Alien::Base::ModuleBuild::Repository->new({ 
  protocol => 'ftp',
  host => 'ftp.gnu.org',
  folder => '/gnu/gsl',
  src => {},
});

my $files = $repo->probe();
is( ref $files, 'ARRAY', 'without pattern, probe returns arrayref');
ok( scalar @$files, 'GSL has available files');

my $pattern = qr/^gsl-[\d\.]+\.tar\.gz\.sig$/;
$repo->{src}{pattern} = $pattern;
$files = $repo->probe();
my @non_matching = grep{ $_ !~ $pattern } @$files;
is( ref $files, 'ARRAY', 'with non-capturing pattern, probe returns arrayref');
ok( ! @non_matching, 'with non-capturing pattern, only matching results are returned' );

my $tempdir = File::Temp->newdir();
ok( -d "$tempdir", 'Temporary folder exists');
my $file = $files->[0];
$repo->get_file($file, $tempdir);
{
  local $CWD = "$tempdir";
  ok( -e $file, 'Downloaded file exists');
}

#reset
$repo->{src}{files} = [];

$pattern = qr/^gsl-([\d\.])+\.tar\.gz$/;
$repo->{src}{pattern} = $pattern;
$files = $repo->probe();
is( ref $files, 'HASH', 'with capturing pattern, probe returns hashref');

done_testing;

