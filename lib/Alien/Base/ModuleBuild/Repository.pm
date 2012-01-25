package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

use Carp;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;

use Alien::Base::ModuleBuild::File;

sub new {
  my $class = shift;
  my ($spec) = @_;

  my $protocol = $spec->{protocol} = uc $spec->{protocol};
  croak "Unsupported protocol: $protocol" 
    unless grep {$_ eq $protocol} qw/FTP HTTP/; 

  my $obj = bless $spec, "Alien::Base::ModuleBuild::Repository::$protocol";

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
  my $platform = shift || 'src';

  croak "Unknown platform $platform"
    unless exists $self->{$platform};

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

  if ($self->_has_capture_groups($pattern)) {
    foreach my $file (@files) {
      $file->{version} = $1 if $file =~ $pattern;
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

