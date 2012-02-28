package Alien::Base;

use strict;
use warnings;

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
  my $cflags = $self->config('cflags');

  # if $cflags is a string, return it
  return $cflags unless ref $cflags;

  # otherwise $cflags is an arrayref
  my @cflags = map { 
    my $cflags = $_;
    $cflags =~ s/^-I(.*)/-I$self->rel2abs_share($1)/e;
    $cflags;
  } @$cflags;

  return join( ' ', @libs );
}

sub libs {
  my $self = shift;
  my $libs = $self->config('libs');

  # if $libs is a string, return it
  return $libs unless ref $libs;

  # otherwise $libs is an arrayref
  my @libs = map { 
    my $lib = $_;
    $lib =~ s/^-L(.*)/-L$self->rel2abs_share($1)/e;
    $lib;
  } @$libs;

  return join( ' ', @libs );
}

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $self = shift;
  return $self->{config}->config(@_);
}

sub rel2abs_share {
  my $self  = shift;
  my ($rel) = @_;

  my $share = $self->{share};

  local $CWD = $share;
  # special case if relative path is '.'
  return "$CWD" if $rel eq '.';

  push @CWD, $rel;

  return "$CWD";
}

1;

