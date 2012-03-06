package Alien::Base;

use strict;
use warnings;

use Carp;

use File::chdir;
use File::ShareDir qw/dist_dir/;
use Scalar::Util qw/blessed/;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

sub import {
  my $class = shift;

  my $config = $class . '::ConfigData';
  eval "require $config";

  my $libs = $class->libs;

  my @L = $libs =~ /-L(\S+)/g;
  for my $var ( qw/LD_RUN_PATH/ ) {
    my @LL = @L;
    unshift @LL, $ENV{$var} if $ENV{$var};

    no strict 'refs';
    $ENV{$var} = join( ':', @LL ) 
      unless ${ $class . "::AlienEnv" }{$var}++;
      # %Alien::MyLib::AlienEnv has keys like ENV_VAR => int
  }
}

sub _find_dist_dir {
  my $class = shift;

  my $dist = $class;
  $dist =~ s/::/-/g;

  return eval { dist_dir $dist } or $class->{build_share_dir};
}

sub new { return bless {}, $_[0] }

sub cflags {
  my $self = shift;
  return $self->_keyword('Cflags', @_);
}

sub libs {
  my $self = shift;
  return $self->_keyword('Libs', @_);
}

sub _keyword {
  my $self = shift;
  my $keyword = shift;

  my $dist_dir = $self->_find_dist_dir;
  my @pc = $self->pkgconfig(@_);
  my @strings = 
    map { $_->keyword($keyword, { alien_dist_dir => $dist_dir }) }
    @pc;

  return join( ' ', @strings );
}

sub pkgconfig {
  my $self = shift;
  my %all = %{ $self->config('pkgconfig') };
  return values %all unless @_;
  return @all{@_};
}

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $class = shift;
  $class = blessed $class || $class;
  
  my $config = $class . '::ConfigData';
  return $config->config(@_);
}

1;

