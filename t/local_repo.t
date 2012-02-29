use strict;
use warnings;

use Test::More;

use File::Basename qw/fileparse/;

use Alien::Base::ModuleBuild::Repository::LOCAL;

my $repo = bless { location => 't' }, 'Alien::Base::ModuleBuild::Repository::LOCAL';

my @files = $repo->list_files;
my $this_file = fileparse __FILE__;

ok( grep { $_ eq $this_file } @files, "found this file" );

done_testing;

