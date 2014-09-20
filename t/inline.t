use strict;
use warnings;
use Test::More;

BEGIN {
  eval { require Inline; require Inline::C; } || plan skip_all => 'test requires Inline and Inline::C';
  eval { require Acme::Alien::DontPanic; } || plan skip_all => 'test requires Acme::Alien::DontPanic '.$@;
}

use Acme::Alien::DontPanic;
use Inline with => 'Acme::Alien::DontPanic';
use Inline C => 'DATA';

is string_answer(), "the answer to life the universe and everything is 42";

done_testing;

__DATA__
__C__

#include <libdontpanic.h>
#include <stdio.h>

char *string_answer()
{
  static char buffer[1024];
  sprintf(buffer, "the answer to life the universe and everything is %d", answer());
  return buffer;
}
