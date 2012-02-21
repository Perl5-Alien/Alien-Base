use strict;
use warnings;

use Test::More tests => 2;

use_ok('Alien::Base::ModuleBuild::File');

my $file = Alien::Base::ModuleBuild::File->new();
isa_ok( $file, 'Alien::Base::ModuleBuild::File');

