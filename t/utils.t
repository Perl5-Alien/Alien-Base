use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild::Utils', 'find_anchor_targets');

my $html = q#Some <a href=link>link text</a> stuff. And a little <A HREF="link2">different link text</a>. <!--  <a href="dont_follow.html">you can't see me!</a> -->#;

my @targets = find_anchor_targets($html);

is_deeply( \@targets, [qw/link link2/], "parse HTML for anchor targets");

done_testing;

