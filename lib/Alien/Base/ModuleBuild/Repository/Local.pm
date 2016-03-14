package Alien::Base::ModuleBuild::Repository::Local;

use strict;
use warnings;

our $VERSION = '0.028';
$VERSION = eval $VERSION;

use Carp;
use File::chdir;
use File::Copy qw/copy/;
use File::Spec;

use parent 'Alien::Base::ModuleBuild::Repository';

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  # make location absolute
  local $CWD = $self->location;
  $self->location("$CWD");

  return $self;
}

sub list_files { 
  my $self = shift;

  local $CWD = $self->location;

  opendir( my $dh, $CWD);
  my @files = 
    grep { ! /^\./ }
    readdir $dh;

  return @files;
}

sub get_file  { 
  my $self = shift;
  my $file = shift || croak "Must specify file to copy";
  
  my $full_file = do {
    local $CWD = $self->location;
    croak "Cannot find file: $file" unless -e $file;
    File::Spec->rel2abs($file);
  };

  copy $full_file, $CWD;

  return $file;
}

1;

