package Alien::Base::ModuleBuild::File;

use strict;
use warnings;
use Carp;
use Digest::SHA;

our $VERSION = '0.004';
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
  $filename = $self->repository->get_file($filename);
  ## verify that the SHA-1 and/or SHA-256 sums match if provided
  if (defined $self->{sha1}) {
    my $sha = Digest::SHA->new(1);
    $sha->addfile($filename);
    unless ($sha->hexdigest eq $self->{sha1}) {
        carp "SHA-1 of downloaded $filename is ", $sha->hexdigest,
        " Expected: ", $self->{sha1};
        return undef;
    }
  }
  if (defined $self->{sha256}) {
    my $sha = Digest::SHA->new(256);
    $sha->addfile($filename);
    unless ($sha->hexdigest eq $self->{sha256}) {
        carp "SHA-256 of downloaded $filename is ", $sha->hexdigest,
        " Expected: ", $self->{sha256};
        return undef;
    }
  }
  return $filename;
}

sub platform   { shift->{platform}   }
sub repository { shift->{repository} }
sub version    { shift->{version}    }
sub filename   { shift->{filename}   }

1;

