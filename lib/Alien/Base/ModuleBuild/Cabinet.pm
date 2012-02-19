package Alien::Base::ModuleBuild::Cabinet;

use strict;
use warnings;

use Sort::Versions;
use List::MoreUtils qw/part/;

sub new {
  my $class = shift;
  my $self = ref $_[0] ? shift : { @_ };

  bless $self, $class;

  return $self;
}

sub files { shift->{files} }

sub add_files {
  my $self = shift;
  push @{ $self->{files} }, @_;
  return $self->files;
}

sub sort_files {
  my $self = shift;

  # split files which have versions and those which don't (sorted on filename)
  my ($name, $version) = part { $_->has_version } @{ $self->{files} };

  # store the sorted lists of versioned, then non-versioned
  my @sorted;
  push @sorted, sort { versioncmp($b,$a) } @$version;
  push @sorted, sort { versioncmp($b,$a) } @$name;

  $self->{files} = \@sorted;

  return;
}

1;

