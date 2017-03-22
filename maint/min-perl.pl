#!/usr/bin/env perl

use strict;
use warnings;

my $ver = shift @ARGV;

die "usage: $0 version command" unless defined $ver;

if($] >= $ver)
{
  exec @ARGV;
}
else
{
  print STDERR "skipping on Perl $]\n";
}
