package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

our $VERSION = '0.028';
$VERSION = eval $VERSION;

use Carp;

use Alien::Base::ModuleBuild::File;
use Alien::Base::ModuleBuild::Utils qw/pattern_has_capture_groups/;

sub new {
  my $class = shift;
  my (%self) = ref $_[0] ? %{ shift() } : @_;

  my $obj = bless \%self, $class;

  $obj->{c_compiler_required} = 1
    unless defined $obj->{c_compiler_required};

  if($obj->{exact_filename} && $obj->{location} !~ m{/$}) {
    $obj->{location} .= '/'
  }

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

  my @files;

  if ($self->{exact_filename}) {
    # if filename provided, use that specific file
    @files = ($self->{exact_filename});    
  } else {
    @files = $self->list_files();

    if ($pattern) {
      @files = grep { $_ =~ $pattern } @files;
    }

    carp "Could not find any matching files" unless @files;
  }

  @files = map { +{ 
    repository => $self,
    platform   => $self->{platform},
    filename   => $_,
  } } @files;

  if ($self->{exact_filename} and $self->{exact_version}) {
    # if filename and version provided, use a specific version
    $files[0]->{version} = $self->{exact_version};
    $files[0]->{sha1} = $self->{sha1} if defined $self->{sha1};
    $files[0]->{sha256} = $self->{sha256} if defined $self->{sha256};
  } elsif ($pattern and pattern_has_capture_groups($pattern)) {
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
# get_file must return filename actually used
sub get_file  { croak "$_[0] doesn't provide 'get_files' method"  }

1;

