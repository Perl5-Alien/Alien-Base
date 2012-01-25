use strict;
use warnings;

use Test::More tests => 4;

use_ok('Alien::Base::ModuleBuild::Cabinet');

my $cab = Alien::Base::ModuleBuild::Cabinet->new();
isa_ok( $cab, 'Alien::Base::ModuleBuild::Cabinet');

# make some fake file objects
my @fake_files = map { bless {}, 'Alien::Base::ModuleBuild::File' } (1..3);

my $add_return = $cab->add_files( @fake_files );
my $accessor_return = $cab->files;

is_deeply( \@fake_files, $accessor_return, "add_files, well ... adds files");
is_deeply( \@fake_files, $add_return, "add_files also returns the files" );

