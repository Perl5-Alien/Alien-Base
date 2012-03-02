package Ford::Prefect;

use strict;
use warnings;

use Alien::DontPanic;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

#use XSLoader;
#XSLoader::load;

require DynaLoader;
our @ISA = 'DynaLoader';
__PACKAGE__->bootstrap($VERSION);

1;

