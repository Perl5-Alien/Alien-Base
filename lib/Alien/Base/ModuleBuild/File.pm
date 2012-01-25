package Alien::Base::ModuleBuild::File;

use strict;
use warnings;

sub new {
  my $class = shift;
  my ($opts) = ref $_[0] ? shift : @_;

  bless $opts, $class;

  return $opts;

}

sub repository { shift->{repository} }
sub version    { shift->{version}    }
sub filename   { shift->{filename}   }

1;

