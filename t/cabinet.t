use strict;
use warnings;

use Test::More tests => 2;

use_ok('Alien::Base::ModuleBuild::Cabinet');

my $cab = Alien::Base::ModuleBuild::Cabinet->new();
isa_ok( $cab, 'Alien::Base::ModuleBuild::Cabinet');

