package Alien::Base::PkgConfig;

use strict;
use warnings;

our $VERSION = '0.016';
$VERSION = eval $VERSION;

use Carp;
use Config;
use File::Basename qw/fileparse/;
use File::Spec;
use Capture::Tiny qw( capture_stderr );

sub new {
  my $class   = shift;

  # allow creation of an object from a full spec.
  if (ref $_[0] eq 'HASH') {
    return bless $_[0], $class;
  }

  my ($path) = @_;
  croak "Must specify a file" unless defined $path;

  $path = File::Spec->rel2abs( $path );

  my ($name, $dir) = fileparse $path, '.pc';

  $dir = File::Spec->catdir( $dir );  # remove trailing slash
  $dir =~ s{\\}{/}g;

  my $self = {
    package  => $name,
    vars     => { pcfiledir => $dir },
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
  die "make_abstract needs a key (and possibly a value)" unless @_;
  my ($var, $value) = @_;

  $value = defined $value ? $value : $self->{vars}{$var};
    
  # convert other vars
  foreach my $key (keys %{ $self->{vars} }) {
    next if $key eq $var; # don't overwrite the current var
    $self->{vars}{$key} =~ s/\Q$value\E/\$\{$var\}/g;
  }

  # convert keywords
  foreach my $key (keys %{ $self->{keywords} }) {
    $self->{keywords}{$key} =~ s/\Q$value\E/\$\{$var\}/g;
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

my $pkg_config_command;

sub pkg_config_command {
  unless (defined $pkg_config_command) {
    capture_stderr {
    
      # For now we prefer PkgConfig.pm over pkg-config on
      # Solaris 64 bit Perls.  We may need to do this on
      # other platforms, in which case this logic should
      # be abstracted so that it can be shared here and
      # in Build.PL

      if (`pkg-config --version` && $? == 0 && !($^O eq 'solaris' && $Config{ptrsize} == 8)) {
        $pkg_config_command = 'pkg-config';
      } else {
        require PkgConfig;
        $pkg_config_command = "$^X $INC{'PkgConfig.pm'}";
      }
    }
  }
  
  $pkg_config_command;
}

1;

