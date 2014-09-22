use strict;
use warnings;
use Test::More;

BEGIN {
  eval { require Inline; require Inline::C; } || plan skip_all => 'test requires Inline and Inline::C';
  eval q{ use Acme::Alien::DontPanic 0.007; 1 } || plan skip_all => 'test requires Acme::Alien::DontPanic 0.007' . $@;
}

plan skip_all => 'test requires that Acme::Alien::DontPanic was build with Alien::Base 0.006'
  unless defined Acme::Alien::DontPanic->Inline("C")->{AUTO_INCLUDE};

use Acme::Alien::DontPanic;
use Inline with => 'Acme::Alien::DontPanic';
use Inline C => 'DATA', ENABLE => 'AUTOWRAP';

is string_answer(), "the answer to life the universe and everything is 42", "indirect call";
is answer(), 42, "direct call";

done_testing;

__DATA__
__C__

#include <stdio.h>

char *string_answer()
{
  static char buffer[1024];
  sprintf(buffer, "the answer to life the universe and everything is %d", answer());
  return buffer;
}

extern int answer();
