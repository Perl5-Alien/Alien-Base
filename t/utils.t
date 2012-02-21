use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild::Utils', 'find_anchor_targets', 'pattern_has_capture_groups');

# replicated in http.t
my $html = q#Some <a href=link>link text</a> stuff. And a little <A HREF="link2">different link text</a>. <!--  <a href="dont_follow.html">you can't see me!</a> -->#;

my @targets = find_anchor_targets($html);

is_deeply( \@targets, [qw/link link2/], "parse HTML for anchor targets");

my $pattern_zero = qr/[a-z]/;
my $pattern_one = qr/[a-z](.)/;
my $pattern_two = qr/[a-z](.)(.)/;

is( pattern_has_capture_groups($pattern_zero), 0, "No capture groups");
is( pattern_has_capture_groups($pattern_one), 1, "One capture group");
is( pattern_has_capture_groups($pattern_two), 2, "Two capture group");

done_testing;

