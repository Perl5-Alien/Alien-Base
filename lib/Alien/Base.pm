package Alien::Base;

use strict;
use warnings;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

sub new {
  my $class = shift;

  my $config = $class . '::ConfigData';
  eval "require $config";
  
  my $self = {
    config => $config,
  };

  bless $self, $class;

  return $self;
}

sub cflags {
  my $self = shift;
  my $cflags = $self->config('cflags');
  return $cflags;
}

sub libs {
  my $self = shift;
  my $libs = $self->config('libs');
  return $libs;
}

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $self = shift;
  return $self->{config}->config(@_);
}

1;

