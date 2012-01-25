package Alien::Base::ModuleBuild::Cabinet;

use strict;
use warnings;

sub new {
  my $class = shift;
  my ($self) = ref $_[0] ? shift : { @_ };

  bless $self, $class;

  return $self;
}

sub files { shift->{files} }

sub add_files {
  my $self = shift;
  push @{ $self->{files} }, @_;
  return $self->files;
}

1;

