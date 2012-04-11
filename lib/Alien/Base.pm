package Alien::Base;

use strict;
use warnings;

our $VERSION = '0.000_008';
$VERSION = eval $VERSION;

use Carp;

use File::chdir;
use File::ShareDir ();
use Scalar::Util qw/blessed/;
use Perl::OSType qw/is_os_type/;
use Config;
use Capture::Tiny qw/capture_merged/;

sub import {
  my $class = shift;

  return if $class->install_type('system');

  my $libs = $class->libs;

  my @L = $libs =~ /-L(\S+)/g;

  #TODO investigate using Env module for this (VMS problems?)
  my $var = is_os_type('Windows') ? 'PATH' : 'LD_RUN_PATH';

  unshift @L, $ENV{$var} if $ENV{$var};

  #TODO check if existsin $ENV{$var} to prevent "used once" warnings

  no strict 'refs';
  $ENV{$var} = join( $Config::Config{path_sep}, @L ) 
    unless ${ $class . "::AlienEnv" }{$var}++;
    # %Alien::MyLib::AlienEnv has keys like ENV_VAR => int (true if loaded)

}

sub dist_dir {
  my $class = shift;

  my $dist = blessed $class || $class;
  $dist =~ s/::/-/g;

  # This line will not work as expected when upgrading (i.e. when a version is already installed, but installing a new version)
  my $dist_dir = eval { File::ShareDir::dist_dir($dist) } || $class->config('build_share_dir');

  return $dist_dir;
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

sub install_type {
  my $self = shift;
  my $type = $self->config('install_type');
  return @_ ? $type eq $_[0] : $type;
}

sub _keyword {
  my $self = shift;
  my $keyword = shift;

  # use pkg-config if installed system-wide
  if ($self->install_type('system')) {
    my $name = $self->config('name');
    my $command = "pkg-config --\L$keyword\E $name";

    chomp ( my $pcdata = capture_merged { system( $command ) } );
    croak "Could not call pkg-config: $!" if $!;

    $pcdata =~ s/\s*$//;

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

  croak "No Alien::Base::PkgConfig objects are stored!"
    unless keys %all;
  
  # Run through all pkgconfig objects and ensure that their modules are loaded:
  for my $pkg_obj (values %all) {
    my $perl_module_name = blessed $pkg_obj;
    eval "require $perl_module_name"; 
  }

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
  warn $@ if $@;

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

