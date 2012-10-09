package Alien::Base::PkgConfig;

use strict;
use warnings;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Carp;
use File::Basename qw/fileparse/;

sub new {
  my $class   = shift;

  # allow creation of an object from a full spec.
  if (ref $_[0] eq 'HASH') {
    return bless $_[0], $class;
  }

  my ($path) = @_;
  croak "Must specify a file" unless defined $path;

  my $name = fileparse $path, '.pc';

  my $self = {
    package  => $name,
    vars     => {},
    keywords => {},
  };

  bless $self, $class;

  $self->read($path);

  return $self;
}

sub read {
  my $self = shift;
  my ($path) = @_;

  open my $fh, '<', $path
    or croak "Cannot open .pc file $path: $!";

  while (<$fh>) {
    if (/(.*?)=([^\n\r]*)/) {
      $self->{vars}{$1} = $2;
    } elsif (/^(.*?):\s*([^\n\r]*)/) {
      $self->{keywords}{$1} = $2;
    }
  }
}

# getter/setter for vars
sub var {
  my $self = shift;
  my ($var, $newval) = @_;
  if (defined $newval) {
    $self->{vars}{$var} = $newval;
  }
  return $self->{vars}{$var};
}

# abstract keywords and other vars in terms of "pure" vars
sub make_abstract {
  my $self = shift;
  my ($top_var, $top_val) = @_;

  my @vars = 
    sort { length $self->{vars}{$b} <=> length $self->{vars}{$a} }
    grep { $self->{vars}{$_} !~ /\$\{.*?\}/ } # skip vars which contain vars
    keys %{ $self->{vars} };

  if ($top_var) {
    @vars = grep { $_ ne $top_var } @vars;
    unshift @vars, $top_var;

    $self->{vars}{$top_var} = $top_val if defined $top_val;
  }

  foreach my $var (@vars) {
    my $value = $self->{vars}{$var};
    next if $value =~ /\$\{.*?\}/; # skip vars which contain vars
    
    # convert other vars
    foreach my $key (keys %{ $self->{vars} }) {
      next if $key eq $var; # don't overwrite the current var
      $self->{vars}{$key} =~ s/$value/\$\{$var\}/g;
    }

    # convert keywords
    foreach my $key (keys %{ $self->{keywords} }) {
      $self->{keywords}{$key} =~ s/$value/\$\{$var\}/g;
    }
  }
}

sub _interpolate_vars {
  my $self = shift;
  my ($string, $override) = @_;

  $override ||= {};

  foreach my $key (keys %$override) {
    carp "Overriden pkg-config variable $key, contains no data" 
      unless $override->{$key};
  }

  1 while $string =~ s/\$\{(.*?)\}/$override->{$1} || $self->{vars}{$1}/e;

  return $string;
}

sub keyword {
  my $self = shift;
  my ($keyword, $override) = @_;
  
  {
    no warnings 'uninitialized';
    croak "overrides passed to 'keyword' must be a hashref"
      if defined $override and ref $override ne 'HASH';
  }

  return $self->_interpolate_vars( $self->{keywords}{$keyword}, $override );
}

1;

