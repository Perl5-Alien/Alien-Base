package Alien::Base::PkgConfig;

use strict;
use warnings;

use Carp;
use File::Basename qw/fileparse/;

sub new {
  my $class   = shift;
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
    if (/(.*?)=(.*)/) {
      $self->{vars}{$1} = $2;
    } elsif (/^(.*?):\s*(.*)/) {
      my $keyword = $1;
      my $value   = $2;

      if ( grep {$keyword eq $_} qw/Name Description URL Version/ ) {
        $self->{keywords}{$keyword} = $value;
      } else {
        $self->{keywords}{$keyword} = [ split /\s+/, $value ];
      }
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
  my @vars = 
    sort { length $self->{vars}{$b} <=> length $self->{vars}{$a} }
    grep { $self->{vars}{$_} !~ /\$\{.*?\}/ } # skip vars which contain vars
    keys %{ $self->{vars} };

  foreach my $var (@vars) {
    my $value = $self->{vars}{$var};
    next if $value =~ /\$\{.*?\}/; # skip vars which contain vars
    
    # convert other vars
    foreach my $key (keys %{ $self->{vars} }) {
      next if $key eq $var; # don't overwrite the current var
      $self->{vars}{$key} =~ s/$value/\$\{$var\}/g;
    }

    foreach my $key (keys %{ $self->{keywords} }) {
      if (ref $self->{keywords}{$key}) {
        s/$value/\$\{$var\}/g for @{ $self->{keywords}{$key} };
      } else {
        $self->{keywords}{$key} =~ s/$value/\$\{$var\}/g;
      }
    }
  }
}

1;

