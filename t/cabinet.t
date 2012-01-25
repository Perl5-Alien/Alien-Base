use strict;
use warnings;

use Test::More tests => 4;

use_ok('Alien::Base::ModuleBuild::Cabinet');

my $cab = Alien::Base::ModuleBuild::Cabinet->new();
isa_ok( $cab, 'Alien::Base::ModuleBuild::Cabinet');

# make some fake file objects
my @fake_files = map { bless {}, 'Alien::Base::ModuleBuild::File' } (1..3);

is_deeply( $cab->add_files( @fake_files ), \@fake_files, "add_files the files" );
is_deeply( $cab->files, \@fake_files, "add_files, well ... adds files");

