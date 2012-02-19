package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

use Carp;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;
use Alien::Base::ModuleBuild::Repository::TEST;

use Alien::Base::ModuleBuild::File;

sub new {
  my $base = shift;
  my $self;

  # allow building from a base object
  my $spec = ref $_[0] ? shift : { @_ };
  if (ref $base) {
    # if first arg was an object, use it for generics
    $self = $base;
    # then override with specifics
    $self->{$_} = $spec->{$_} for keys %$spec;
    # default to 'src' platform if not otherwise given
    $self->{platform} = 'src' unless $self->{platform};

  } else {
    # if first arg was not an object, only use specific
    $self = $spec;
  }

  my $protocol = $self->{protocol} = uc $self->{protocol};
  croak "Unsupported protocol: $protocol" 
    unless grep {$_ eq $protocol} qw/FTP HTTP TEST/; 

  my $obj = bless $self, "Alien::Base::ModuleBuild::Repository::$protocol";

  return $obj;
}

sub protocol { return shift->{protocol} }

sub host {
  my $self = shift;
  $self->{host} = shift if @_;
  return $self->{host};
}

sub folder {
  my $self = shift;
  $self->{folder} = shift if @_;
  return $self->{folder};
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

  if ($pattern and $self->_has_capture_groups($pattern)) {
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

sub _has_capture_groups {
  my $self = shift;
  my $re = shift;
  "" =~ /|$re/;
  return $#+;
}

1;

