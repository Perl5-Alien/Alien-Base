package Alien::Base::ModuleBuild::File;

use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = ref $_[0] ? shift : { @_ };

  bless $self, $class;

  return $self;
}

sub platform   { shift->{platform}   }
sub repository { shift->{repository} }
sub version    { shift->{version}    }
sub filename   { shift->{filename}   }

1;

