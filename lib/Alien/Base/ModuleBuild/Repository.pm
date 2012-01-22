package Alien::Base::ModuleBuild::Repository;

use strict;
use warnings;

use Carp;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;

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

  my @files;
  if (scalar keys %{ $self->{$platform}{versions} || {} }) {

    return $self->{$platform}{versions};

  } elsif (scalar @{ $self->{$platform}{files} || [] }) {

    return $self->{$platform}{files}
      unless $pattern;

    @files = @{ $self->{$platform}{files} };

  } else {

    @files = $self->list_files();
    
    $self->{$platform}{files} = \@files;

    return \@files unless $pattern;

  }

  # only get here if $pattern exists

  @files = grep { $_ =~ $pattern } @files;
  carp "Could not find any matching files" unless @files;
  $self->{$platform}{files} = \@files;

  return \@files
    unless $self->_has_capture_groups($pattern);

  my %versions = map { 
    ($_ =~ $pattern and defined $1) ? ( $1 => $_ ) : ()
  } @files;

  if (scalar keys %versions) {
    $self->{$platform}{versions} = \%versions;
    return \%versions;
  } else {
    return \@files;
  }
  
}

sub _has_capture_groups {
  my $self = shift;
  my $re = shift;
  "" =~ /|$re/;
  return $#+;
}

1;

