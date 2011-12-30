use strict;
use warnings;

use File::chdir;

use Test::More;
use_ok( 'Alien::Base::ModuleBuild' );

my $builder = bless { 
  alien_source_ftp => { 
    server => 'ftp.gnu.org',
    folder => '/gnu/gsl',
  }
}, 'Alien::Base::ModuleBuild';

my $files = $builder->alien_probe_ftp('source');
is( ref $files, 'ARRAY', 'without pattern, alien_probe_ftp returns arrayref');
ok( scalar @$files, 'GSL has available files');

my $pattern = qr/^gsl-[\d\.]+\.tar\.gz\.sig$/;
$builder->{alien_source_ftp}{pattern} = $pattern;
$files = $builder->alien_probe_ftp('source');
my @non_matching = grep{ $_ !~ $pattern } @$files;
is( ref $files, 'ARRAY', 'with non-capturing pattern, alien_probe_ftp returns arrayref');
ok( ! @non_matching, 'with non-capturing pattern, only matching results are returned' );

my $tempdir = $builder->alien_temp_folder;
ok( -d "$tempdir", 'Temporary folder exists');
my $file = $files->[0];
$builder->alien_get_file_ftp('source', $file);
{
  local $CWD = "$tempdir";
  ok( -e $file, 'Downloaded file exists');
}

#reset
$builder->{alien_source_ftp}{data}{files} = [];

$pattern = qr/^gsl-([\d\.])+\.tar\.gz$/;
$builder->{alien_source_ftp}{pattern} = $pattern;
$files = $builder->alien_probe_ftp('source');
is( ref $files, 'HASH', 'with capturing pattern, alien_probe_ftp returns hashref');

done_testing;

