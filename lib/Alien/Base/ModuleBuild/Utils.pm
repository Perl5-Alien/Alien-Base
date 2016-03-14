package Alien::Base::ModuleBuild::Utils;
# some useful functions for A::B::MB code

use strict;
use warnings;

our $VERSION = '0.028';
$VERSION = eval $VERSION;

use Text::Balanced qw/extract_bracketed extract_delimited extract_multiple/;

use parent 'Exporter';
our @EXPORT_OK = qw/find_anchor_targets pattern_has_capture_groups/;

sub find_anchor_targets {
  my $html = shift;

  my @tags = extract_multiple( 
    $html, 
    [ sub { extract_bracketed($_[0], '<>') } ],
    undef, 1
  );

  @tags = 
    map { extract_href($_) }  # find related href=
    grep { /^<a/i }            # only anchor begin tags
    @tags;

  return @tags;
}

sub extract_href {
  my $tag = shift;
  if($tag =~ /href=(?='|")/gci) {
    my $text = scalar extract_delimited( $tag, q{'"} );
    my $delim = substr $text, 0, 1;
    $text =~ s/^$delim//;
    $text =~ s/$delim$//;
    return $text;
  } elsif ($tag =~ /href=(.*?)(?:\s|\n|>)/i) {
    return $1;
  } else {
    return ();
  }
}

sub pattern_has_capture_groups {
  my $re = shift;
  "" =~ /|$re/;
  return $#+;
}


1;


