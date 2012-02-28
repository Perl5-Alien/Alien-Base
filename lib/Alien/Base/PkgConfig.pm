package Alien::Base::PkgConfig;

use strict;
use warnings;

use Carp;
use File::Basename qw/fileparse/;

sub new {
  my $class   = shift;
  my ($path) = @_;
  croak "Must specify a file" unless defined $path;

  my $name = fileparse $path, '.pc';

  my $self = {
    package  => $name,
    vars     => {},
    keywords => {},
  };

  bless $self, $class;

  $self->read($path);

  return $self;
}

sub read {
  my $self = shift;
  my ($path) = @_;

  open my $fh, '<', $path
    or croak "Cannot open .pc file $path: $!";

  while (<$fh>) {
    if (/(.*?)=(.*)/) {
      $self->{vars}{$1} = $2;
    } elsif (/^(.*?):\s+(.*)/) {
      my $keyword = $1;
      my $value   = $2;

      if ( grep {$keyword eq $_} qw/Name Description URL Version/ ) {
        $self->{keywords}{$keyword} = $value;
      } else {
        $self->{keywords}{$keyword} = [ split /\s+/, $value ];
      }
    }
  }
}

1;

