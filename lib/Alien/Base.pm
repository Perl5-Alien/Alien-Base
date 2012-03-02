package Alien::Base;

use strict;
use warnings;

use Carp;

use File::chdir;
use File::ShareDir qw/dist_dir/;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

sub new {
  my $class = shift;

  my $config = $class . '::ConfigData';
  eval "require $config";

  my $dist = $class;
  $dist =~ s/::/-/g;

  my $dist_dir = dist_dir $dist;
  
  my $self = {
    config => $config,
    share  => $dist_dir,
  };

  bless $self, $class;

  return $self;
}

sub cflags {
  my $self = shift;
  my $package = shift;
  my $pc = $self->config('pkgconfig')->{$package};
  return $pc->keyword('Cflags', { alien_dist_dir => $self->{share} });
}

sub libs {
  my $self = shift;
  my $package = shift;
  my $pc = $self->config('pkgconfig')->{$package};
  return $pc->keyword('Libs', { alien_dist_dir => $self->{share} });
}

sub pkgconfig {
  my $self = shift;
  my ($pc_file) = @_;
  croak "Must specify a package" unless $pc_file;

  return $self->config('pkgconfig')->{$pc_file};
}

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $self = shift;
  return $self->{config}->config(@_);
}

1;

