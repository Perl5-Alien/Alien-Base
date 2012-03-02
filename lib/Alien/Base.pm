package Alien::Base;

use strict;
use warnings;

use Carp;

use File::chdir;
use File::ShareDir qw/dist_dir/;
use Scalar::Util qw/blessed/;
use List::MoreUtils qw/part/;

require DynaLoader;
#use autodynaload;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

sub import {
  my $class = shift;

  my $config = $class . '::ConfigData';
  eval "require $config";

  my $dist_dir = $class->_find_dist_dir;

  my ($l, $L) = part { /^-L/ } split /\s+/, $class->libs;
  #my %libs = 
  #  map { 
  #    ( my $lib = $_ ) =~ s/^-l//;
  #    ( $lib, DynaLoader::dl_findfile( @$L, $_ ) );
  #  } 
  #  @$l;

  #autodynaload->new( sub { $libs{$_[1]} } )->insert(0);

  #$ENV{'LD_LIBRARY_PATH'} = join (':', map { my $in = $_; $in=~s/^-L//; $in } @$L); 
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

