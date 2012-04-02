use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild::Repository::HTTP');

my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new;

# replicated in utils.t
my $html = q#Some <a href=link>link text</a> stuff. And a little <A HREF="link2">different link text</a>. AN ALL CAPS TAG <A HREF="link3">ALL CAPS</A> <A HREF=link4>ALL CAPS NO QUOTES</A>. <!--  <a href="dont_follow.html">you can't see me!</a> -->#;
my $correct = [qw/link link2 link3 link4/];

SKIP: {
  no warnings 'once';
  skip "HTML::LinkExtor not detected", 2 
    unless $Alien::Base::ModuleBuild::Repository::HTTP::Has_HTML_Parser; 

  my @targets = $repo->find_links_preferred($html);
  is_deeply( \@targets, $correct, "parse HTML for anchor targets (HTML::LinkExtor)");

  my @disp_targets = $repo->find_links($html);
  is_deeply( \@disp_targets, $correct, "parse HTML for anchor targets (HTML::LinkExtor, dispatched)");
}

{
  my @targets = $repo->find_links_textbalanced($html);
  is_deeply( \@targets, $correct, "parse HTML for anchor targets (Text::Balanced)");

  # force Text::Balanced in dispatcher
  $Alien::Base::ModuleBuild::Repository::HTTP::Has_HTML_Parser = 0;
  my @disp_targets = $repo->find_links($html);
  is_deeply( \@disp_targets, $correct, "parse HTML for anchor targets (Text::Balanced, dispatched)");
}


done_testing;

