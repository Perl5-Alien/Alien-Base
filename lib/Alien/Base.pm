package Alien::Base;

use strict;
use warnings;

our $VERSION = '0.000_002';
$VERSION = eval $VERSION;

use Carp;

use File::chdir;
use File::ShareDir ();
use Scalar::Util qw/blessed/;
use Perl::OSType qw/is_os_type/;
use Config;

sub import {
  my $class = shift;

  my $libs = $class->libs;

  my @L = $libs =~ /-L(\S+)/g;

  #TODO investigate using Env module for this (VMS problems?)
  my $var = is_os_type('Windows') ? 'PATH' : 'LD_RUN_PATH';
  my @LL = @L;
  unshift @LL, $ENV{$var} if $ENV{$var};

  no strict 'refs';
  $ENV{$var} = join( $Config::Config{path_sep}, @LL ) 
    unless ${ $class . "::AlienEnv" }{$var}++;
    # %Alien::MyLib::AlienEnv has keys like ENV_VAR => int (true if loaded)

}

sub dist_dir {
  my $class = shift;

  my $dist = $class;
  $dist =~ s/::/-/g;

  return eval { File::ShareDir::dist_dir $dist } or $class->{build_share_dir};
}

sub new { return bless {}, $_[0] }

sub cflags {
  my $self = shift;
  return $self->_keyword('Cflags', @_);
}

sub libs {
  my $self = shift;
  return $self->_keyword('Libs', @_);
}

sub _keyword {
  my $self = shift;
  my $keyword = shift;

  # use pkg-config if installed system-wide
  my $type = $self->config('install_type');
  if ($type eq 'system') {
    my $name = $self->config('name');
    my $pcdata = `pkg-config --\L$keyword\E $name`;
    croak "Could not call pkg-config: $!" if $!;
    return $pcdata;
  }

  # use parsed info from build .pc file
  my $dist_dir = $self->dist_dir;
  my @pc = $self->pkgconfig(@_);
  my @strings = 
    map { $_->keyword($keyword, { alien_dist_dir => $dist_dir }) }
    @pc;

  return join( ' ', @strings );
}

sub pkgconfig {
  my $self = shift;
  my %all = %{ $self->config('pkgconfig') };

  return @all{@_} if @_;

  my $manual = delete $all{_manual};

  if (keys %all) {
    return values %all;
  } else {
    return $manual;
  }
}

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $class = shift;
  $class = blessed $class || $class;
  
  my $config = $class . '::ConfigData';
  eval "require $config";

  return $config->config(@_);
}

1;

__END__
__POD__

=head1 NAME

Alien::Base - Base classes for Alien:: modules

=head1 SYNOPSIS

 package Alien::MyLibrary;

 use strict;
 use warnings;

 use parent 'Alien::Base';

 1;

=head1 DESCRIPTION

L<Alien::Base> comprises base classes to help in the construction of C<Alien::> modules. Modules in the L<Alien> namespace are used to locate and install (if necessary) external libraries needed by other Perl modules.

This is the documentation for the L<Alien::Base> module itself. To learn more about the system as a whole please see L<Alien::Base::Authoring>.

=head1 SEE ALSO

=over 

=item * 

L<Module::Build>

=item *

L<Alien>

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/Alien-Base>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

