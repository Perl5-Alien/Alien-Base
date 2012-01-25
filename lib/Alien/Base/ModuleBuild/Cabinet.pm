package Alien::Base::ModuleBuild::Cabinet;

use strict;
use warnings;

sub new {
  my $class = shift;
  my ($opts) = ref $_[0] ? shift : @_;

  bless $opts, $class;

  return $opts;

}

sub files { shift->{files} }

sub add_files {
  my $self = shift;
  push @{ $self->{files} }, @_;
  return $self->files;
}
