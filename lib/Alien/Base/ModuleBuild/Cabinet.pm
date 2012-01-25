package Alien::Base::ModuleBuild::Cabinet;

use strict;
use warnings;

use Sort::Versions;

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

  @{ $self->{files} } 
    = sort { 
      $b->has_version <=> $a->has_version 
      || _versioncmp($b,$a)
    }
    @{ $self->{files} };

  return;
}

####################
# helper function(s)


sub _versioncmp {
  my ($x, $y) = map {
    $_->has_version ? $_->version : $_->filename;
  } @_;
  return versioncmp ( $x, $y );
}

1;

