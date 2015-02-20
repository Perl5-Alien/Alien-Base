use strict;
use warnings;
use Test::More;

BEGIN {
  eval q{ use Inline 0.56 (); require Inline::CPP; } || plan skip_all => 'test requires Inline 0.56 and Inline::CPP';
  eval q{ use Acme::Alien::DontPanic 0.010; 1 } || plan skip_all => 'test requires Acme::Alien::DontPanic 0.010 :' . $@;
  plan skip_all => 'test requires that Acme::Alien::DontPanic was build with Alien::Base 0.006'
    unless defined Acme::Alien::DontPanic->Inline("CPP")->{AUTO_INCLUDE};
}


use Acme::Alien::DontPanic;
use Inline 0.56 with => 'Acme::Alien::DontPanic';
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
