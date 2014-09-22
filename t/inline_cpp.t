use strict;
use warnings;
use Test::More;

BEGIN {
  eval { require Inline; require Inline::CPP; } || plan skip_all => 'test requires Inline and Inline::CPP';
  eval { require Acme::Alien::DontPanic; } || plan skip_all => 'test requires Acme::Alien::DontPanic';
}

use Acme::Alien::DontPanic;
use Inline with => 'Acme::Alien::DontPanic';
use Inline CPP => 'DATA', ENABLE => 'AUTOWRAP';

is Foo->new->string_answer, "the answer to life the universe and everything is 42", 'indirect';
is answer(), 42, "direct";

done_testing;

__DATA__
__CPP__

#include <stdio.h>

class Foo {
public:
  char *string_answer()
  {
    static char buffer[1024];
    sprintf(buffer, "the answer to life the universe and everything is %d", answer());
    return buffer;
  }
};

extern int answer();
