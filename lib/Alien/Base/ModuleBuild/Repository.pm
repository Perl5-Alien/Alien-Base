package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

use Carp;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;
use Alien::Base::ModuleBuild::Repository::TEST;

use Alien::Base::ModuleBuild::File;

sub new {
  my $class = shift;
  my $self = ref $_[0] ? shift : { @_ };

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
  my $platform = shift;

  if (defined $platform) {
    croak "Unknown platform $platform"
      unless exists $self->{$platform};
  } else {
    $platform = 'src';
  }

  my $pattern = $self->{$platform}{pattern};

  my @files = $self->list_files();

  if ($pattern) {
    @files = grep { $_ =~ $pattern } @files;
  }

  carp "Could not find any matching files" unless @files;

  @files = map { +{ 
    repository => $self,
    platform   => $platform,
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

