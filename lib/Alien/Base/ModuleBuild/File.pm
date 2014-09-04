package Alien::Base::ModuleBuild::File;

use strict;
use warnings;

our $VERSION = '0.004_01';
$VERSION = eval $VERSION;

sub new {
  my $class = shift;
  my $self = ref $_[0] ? shift : { @_ };

  bless $self, $class;

  return $self;
}

sub has_version {
  my $self = shift;
  return defined $self->version;
}

sub get {
  my $self = shift;
  my $repo = $self->repository;

  my $filename = $repo->get_file($self->filename);
  if ( my $new_filename = $repo->{new_filename} ) {
    $filename = $self->{filename} = $new_filename;
  }

  return $self->filename;
}

sub platform   { shift->{platform}   }
sub repository { shift->{repository} }
sub version    { shift->{version}    }
sub filename   { shift->{filename}   }

1;

