package Alien::Base::ModuleBuild::File;

use strict;
use warnings;

our $VERSION = '0.000_010';
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
  my $filename = $self->filename;
  $self->repository->get_file($filename);
  return $filename;
}

sub platform   { shift->{platform}   }
sub repository { shift->{repository} }
sub version    { shift->{version}    }
sub filename   { shift->{filename}   }

1;

