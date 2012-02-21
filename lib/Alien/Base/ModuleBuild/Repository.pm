package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

use Carp;

use Module::Loaded qw/is_loaded/;

use Alien::Base::ModuleBuild::File;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;
use Alien::Base::ModuleBuild::Repository::TEST;

# setup protocol specific classes
# Alien:: author can override these defaults using package variable
our %Repository_Class;
my %default_repository_class = (
  HTTP => 'Alien::Base::ModuleBuild::Repository::HTTP',
  FTP  => 'Alien::Base::ModuleBuild::Repository::FTP',
  TEST => 'Alien::Base::ModuleBuild::Repository::TEST',
);
foreach my $type (keys %default_repository_class) {
  $Repository_Class{$type} ||= $default_repository_class{$type};
}

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

  } else {
    # if first arg was not an object, only use specific
    $self = $spec;
  }

  my $protocol = $self->{protocol} = uc $self->{protocol};
  croak "Unsupported protocol: $protocol" 
    unless exists $Repository_Class{$protocol}; 

  my $obj = bless $self, $Repository_Class{$protocol};

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
    platform   => $self->{platform} || 'src',
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

