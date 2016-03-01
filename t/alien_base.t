use strict;
use warnings;
use lib 't/alien_base/ab_share/lib';
use lib 't/alien_base/ab_sys/lib';
use lib 't/alien_base/mb_share/lib';
use lib 't/alien_base/mb_sys/lib';
use Test::More;
use Env qw( @PKG_CONFIG_PATH );
use File::Spec;

unshift @PKG_CONFIG_PATH, File::Spec->rel2abs(File::Spec->catdir( qw( t alien_base pkgconfig )));

subtest 'AB::MB sys install' => sub {

  require_ok 'Alien::Foo1';

  my $cflags = Alien::Foo1->cflags;
  my $libs   = Alien::Foo1->libs;

  is $cflags, '-DFOO=stuff', "cflags: $cflags";
  is $libs,   '-lfoo1', "libs: $libs";
};

subtest 'AB::MB share install' => sub {

  require_ok 'Alien::Foo2';

  my $cflags = Alien::Foo2->cflags;
  my $libs   = Alien::Foo2->libs;
    
  ok $cflags, "cflags: $cflags";
  ok $libs,   "libs:   $libs";

  if($cflags =~ /-I(.*)$/)
  {
    ok -f "$1/foo2.h", "include path: $1";
  }
  else
  {
    fail "include path: ?";
  }
  
  if($libs =~ /-L([^ ]*)/)
  {
    ok -f "$1/libfoo2.a", "lib path: $1";
  }
  else
  {
    fail "lib path: ?";
  }

};

subtest 'A::Builder sys install' => sub {

  require_ok 'Alien::Bar1';

  my $cflags = Alien::Bar1->cflags;
  my $libs   = Alien::Bar1->libs;

  is $cflags, '-DFOO=stuff', "cflags: $cflags";
  is $libs,   '-lbar1', "libs: $libs";
};

subtest 'A::Builder share install' => sub {

  require_ok 'Alien::Bar2';

  my $cflags = Alien::Bar2->cflags;
  my $libs   = Alien::Bar2->libs;

  ok $cflags, "cflags: $cflags";
  ok $libs,   "libs:   $libs";

  if($cflags =~ /-I(.*)$/)
  {
    ok -f "$1/bar2.h", "include path: $1";
  }
  else
  {
    fail "include path: ?";
  }
  
  if($libs =~ /-L([^ ]*)/)
  {
    ok -f "$1/libbar2.a", "lib path: $1";
  }
  else
  {
    fail "lib path: ?";
  }
};

done_testing;

package
  File::ShareDir;

BEGIN { $INC{'File/ShareDir.pm'} = __FILE__ }

use File::Spec;

sub dist_dir
{
  my($dist) = @_;
  if($dist eq 'Alien-Foo2')
  {
    return File::Spec->rel2abs('t/alien_base/mb_share/share');
  }
  elsif($dist eq 'Alien-Bar1')
  {
    return File::Spec->rel2abs('t/alien_base/ab_sys/share');
  }
  elsif($dist eq 'Alien-Bar2')
  {
    return File::Spec->rel2abs('t/alien_base/ab_share/share');
  }
  else
  {
    die "no such share dir for $dist";
  }
}
