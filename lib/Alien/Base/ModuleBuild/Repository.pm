package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

our $VERSION = '0.000_013';
$VERSION = eval $VERSION;

use Carp;

use Alien::Base::ModuleBuild::File;
use Alien::Base::ModuleBuild::Utils qw/pattern_has_capture_groups/;

sub new {
  my $class = shift;
  my (%self) = ref $_[0] ? %{ shift() } : @_;

  my $obj = bless \%self, $class;

  return $obj;
}

sub protocol { return shift->{protocol} }

sub host {
  my $self = shift;
  $self->{host} = shift if @_;
  return $self->{host};
}

sub location {
  my $self = shift;
  $self->{location} = shift if @_;
  return $self->{location};
}

sub probe {
  my $self = shift;

  my $pattern = $self->{pattern};

  my @files = $self->list_files();

  if ($pattern) {
    @files = grep { $_ =~ $pattern } @files;
  }

  carp "Could not find any matching files" unless @files;

  @files = map { +{ 
    repository => $self,
    platform   => $self->{platform},
    filename   => $_,
  } } @files;

  if ($pattern and pattern_has_capture_groups($pattern)) {
    foreach my $file (@files) {
      $file->{version} = $1 
        if $file->{filename} =~ $pattern;
    }
  }

  @files = 
    map { Alien::Base::ModuleBuild::File->new($_) }
    @files;

  return @files;
}

# subclasses are expected to provide 
sub connection { croak "$_[0] doesn't provide 'connection' method" }
sub list_files { croak "$_[0] doesn't provide 'list_files' method" }
sub get_file  { croak "$_[0] doesn't provide 'get_files' method"  }

1;

