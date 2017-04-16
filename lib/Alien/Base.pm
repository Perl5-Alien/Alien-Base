package Alien::Base;

use strict;
use warnings;

our $VERSION = '0.041';

use Carp;
use File::ShareDir ();
use File::Spec;
use Scalar::Util qw/blessed/;
use Capture::Tiny 0.17 qw/capture_merged/;
use Text::ParseWords qw/shellwords/;

=encoding UTF-8

=head1 NAME

Alien::Base - Base classes for Alien:: modules

=head1 SYNOPSIS

 package Alien::MyLibrary;

 use strict;
 use warnings;

 use parent 'Alien::Base';

 1;

(for details on the C<Makefile.PL> or C<Build.PL> and L<alienfile>
that should be bundled with your L<Alien::Base> subclass, please see
L<Alien::Base::Authoring>).

Then a C<MyLibrary::XS> can use C<Alien::MyLibrary> in its C<Build.PL>:

 use Alien::MyLibrary;
 use Module::Build 0.28; # need at least 0.28
 
 my $builder = Module::Build->new(
   ...
   extra_compiler_flags => Alien::MyLibrary->cflags,
   extra_linker_flags   => Alien::MyLibrary->libs,
   ...
 );
 
 $builder->create_build_script;

Or if you prefer L<ExtUtils::MakeMaker>, in its C<Makefile.PL>:

 use Alien::MyLibrary
 use ExtUtils::MakeMaker;
 use Config;
 
 WriteMakefile(
   ...
   CCFLAGS => Alien::MyLibrary->cflags . " $Config{ccflags}",
   LIBS   => ALien::MyLibrary->libs,
   ...
 );

Or if you are using L<ExtUtils::Depends>:

 use ExtUtils::MakeMaker;
 use ExtUtils::Depends;
 my $eud = ExtUtils::Depends->new(qw( MyLibrary::XS Alien::MyLibrary ));
 WriteMakefile(
   ...
   $eud->get_makefile_vars
 );

In your C<MyLibrary::XS> module, you may need to use L<Alien::MyLibrary> if
dynamic libraries are used:

 package MyLibrary::XS;
 
 use Alien::MyLibrary;
 
 ...

Or you can use it from an FFI module:

 package MyLibrary::FFI;
 
 use Alien::MyLibrary;
 use FFI::Platypus;
 
 my $ffi = FFI::Platypus->new;
 $ffi->lib(Alien::MyLibrary->dynamic_libs);
 
 $ffi->attach( 'my_library_function' => [] => 'void' );

You can even use it with L<Inline> (C and C++ languages are supported):

 package MyLibrary::Inline;
 
 use Alien::MyLibrary;
 # Inline 0.56 or better is required
 use Inline 0.56 with => 'Alien::MyLibrary';
 ...

You can even use it with L<Inline> (C and C++ languages are supported):

 package MyLibrary::Inline;
 
 use Alien::MyLibrary;
 use Inline with => 'Alien::MyLibrary';
 ...

=head1 DESCRIPTION

B<NOTE>: L<Alien::Base::ModuleBuild> is no longer bundled with L<Alien::Base> and has been spun off into a separate distribution.
L<Alien::Build::ModuleBuild> will be a prerequisite for L<Alien::Base> until October 1, 2017.  If you are using L<Alien::Base::ModuleBuild>
you need to make sure it is declared as a C<configure_requires> in your C<Build.PL>.  You may want to also consider using L<Alien::Base> and
L<alienfile> as a more modern alternative.

L<Alien::Base> comprises base classes to help in the construction of C<Alien::> modules. Modules in the L<Alien> namespace are used to locate and install (if necessary) external libraries needed by other Perl modules.

This is the documentation for the L<Alien::Base> module itself. To learn more about the system as a whole please see L<Alien::Base::Authoring>.

=cut

sub import {
  my $class = shift;

  return if $class->runtime_prop;

  return if $class->install_type('system');

  require DynaLoader;

  # Sanity check in order to ensure that dist_dir can be found.
  # This will throw an exception otherwise.  
  $class->dist_dir;

  # get a reference to %Alien::MyLibrary::AlienLoaded
  # which contains names of already loaded libraries
  # this logic may be replaced by investigating the DynaLoader arrays
  my $loaded = do {
    no strict 'refs';
    no warnings 'once';
    \%{ $class . "::AlienLoaded" };
  };

  my @libs = $class->split_flags( $class->libs );

  my @L = grep { s/^-L// } @libs;
  my @l = grep { /^-l/ } @libs;

  unshift @DynaLoader::dl_library_path, @L;

  my @libpaths;
  foreach my $l (@l) {
    next if $loaded->{$l};

    my $path = DynaLoader::dl_findfile( $l );
    unless ($path) {
      carp "Could not resolve $l";
      next;
    }

    push @libpaths, $path;
    $loaded->{$l} = $path;
  }

  push @DynaLoader::dl_resolve_using, @libpaths;

  my @librefs = map { DynaLoader::dl_load_file( $_, 0x01 ) } grep !/\.(a|lib)$/, @libpaths;
  push @DynaLoader::dl_librefs, @librefs;

}

=head1 METHODS

In the example snippets here, C<Alien::MyLibrary> represents any
subclass of L<Alien::Base>.

=head2 dist_dir

 my $dir = Alien::MyLibrary->dist_dir;

Returns the directory that contains the install root for
the packaged software, if it was built from install (i.e., if
C<install_type> is C<share>).

=cut

sub dist_dir {
  my $class = shift;

  my $dist = blessed $class || $class;
  $dist =~ s/::/-/g;

  my $dist_dir = 
    $class->config('finished_installing') 
      ? File::ShareDir::dist_dir($dist) 
      : $class->config('working_directory');

  croak "Failed to find share dir for dist '$dist'"
    unless defined $dist_dir && -d $dist_dir;

  return $dist_dir;
}

sub new { return bless {}, $_[0] }

sub _flags
{
  my($class, $key) = @_;
  
  my $config = $class->runtime_prop;
  my $flags = $config->{$key};

  my $prefix = $config->{prefix};
  $prefix =~ s{\\}{/}g if $^O =~ /^(MSWin32|msys)$/;
  my $distdir = $config->{distdir};
  $distdir =~ s{\\}{/}g if $^O =~ /^(MSWin32|msys)$/;
  
  if($prefix ne $distdir)
  {
    $flags = join ' ', map { 
      s/^(-I|-L|-LIBPATH:)?\Q$prefix\E/$1$distdir/;
      s/(\s)/\\$1/g;
      $_;
    } $class->split_flags($flags);
  }
  
  $flags;
}

=head2 cflags

 my $cflags = Alien::MyLibrary->cflags;

 use Text::ParseWords qw( shellwords );
 my @cflags = shellwords( Alien::MyLibrary->cflags );

Returns the C compiler flags necessary to compile an XS
module using the alien software.  If you need this in list
form (for example if you are calling system with a list
argument) you can pass this value into C<shellwords> from
the Perl core L<Text::ParseWords> module.

=cut

sub cflags {
  my $class = shift;
  return $class->runtime_prop ? $class->_flags('cflags') : $class->_pkgconfig_keyword('Cflags');
}

sub cflags_static {
  my $class = shift;
  return $class->runtime_prop ? $class->_flags('cflags_static') : $class->_pkgconfig_keyword('Cflags', 'static');
}

=head2 libs

 my $libs = Alien::MyLibrary->libs;

 use Text::ParseWords qw( shellwords );
 my @cflags = shellwords( Alien::MyLibrary->libs );

Returns the library linker flags necessary to link an XS
module against the alien software.  If you need this in list
form (for example if you are calling system with a list
argument) you can pass this value into C<shellwords> from
the Perl core L<Text::ParseWords> module.

=cut

sub libs {
  my $class = shift;
  return $class->runtime_prop ? $class->_flags('libs') : $class->_pkgconfig_keyword('Libs');
}

sub libs_static {
  my $class = shift;
  return $class->runtime_prop ? $class->_flags('libs_static') : $class->_pkgconfig_keyword('Libs', 'static');
}

=head2 version

 my $version = Alien::MyLibrary->version;

Returns the version of the Alienized library or tool that was
determined at install time.

=cut

sub version {
  my $self = shift;
  my $version = $self->config('version');
  chomp $version;
  return $version;
}

=head2 install_type

 my $install_type = Alien::MyLibrary->install_type;

Returns the install type that was used when C<Alien::MyLibrary> was
installed.  Types include:

=over 4

=item system

The library was provided by the operating system

=item share

The library was not available when C<Alien::MyLibrary> was installed, so
it was built from source code, either downloaded from the Internet
or bundled with C<Alien::MyLibrary>.

=back

=cut

sub install_type {
  my $self = shift;
  my $type = $self->config('install_type');
  return @_ ? $type eq $_[0] : $type;
}

sub _pkgconfig_keyword {
  my $self = shift;
  my $keyword = shift;
  my $static = shift;

  # use pkg-config if installed system-wide
  if ($self->install_type('system')) {
    my $name = $self->config('name');
    require Alien::Base::PkgConfig;
    my $command = Alien::Base::PkgConfig->pkg_config_command . " @{[ $static ? '--static' : '' ]} --\L$keyword\E $name";

    $! = 0;
    chomp ( my $pcdata = capture_merged { system( $command ) } );

    # if pkg-config fails for whatever reason, then we try to
    # fallback on alien_provides_*
    $pcdata = '' if $! || $?;

    $pcdata =~ s/\s*$//;

    if($self->config('system_provides')) {
      if(my $system_provides = $self->config('system_provides')->{$keyword}) {
        $pcdata = length $pcdata ? "$pcdata $system_provides" : $system_provides;
      }
    }

    return $pcdata;
  }

  # use parsed info from build .pc file
  my $dist_dir = $self->dist_dir;
  my @pc = $self->_pkgconfig(@_);
  my @strings =
    grep defined,
    map { $_->keyword($keyword, 
      #{ pcfiledir => $dist_dir }
    ) }
    @pc;

  if(defined $self->config('original_prefix') && $self->config('original_prefix') ne $self->dist_dir)
  {
    my $dist_dir = $self->dist_dir;
    $dist_dir =~ s{\\}{/}g if $^O eq 'MSWin32';
    my $old = quotemeta $self->config('original_prefix');
    @strings = map {
      s{^(-I|-L|-LIBPATH:)?($old)}{$1.$dist_dir}e;
      s/(\s)/\\$1/g;
      $_;
    } map { $self->split_flags($_) } @strings;
  }

  return join( ' ', @strings );
}

sub _pkgconfig {
  my $self = shift;
  my %all = %{ $self->config('pkgconfig') };

  # merge in found pc files
  require File::Find;
  my $wanted = sub {
    return if ( -d or not /\.pc$/ );
    require Alien::Base::PkgConfig;
    my $pkg = Alien::Base::PkgConfig->new($_);
    $all{$pkg->{package}} = $pkg;
  };
  File::Find::find( $wanted, $self->dist_dir );
    
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

=head2 config

 my $value = Alien::MyLibrary->config($key);

Returns the configuration data as determined during the install
of L<Alien::MyLibrary>.  For the appropriate config keys, see 
L<Alien::Base::ModuleBuild::API#CONFIG-DATA>.

This is not typically used by L<Alien::Base> and L<alienfile>,
but a compatible interface will be provided.

=cut

# helper method to call Alien::MyLib::ConfigData->config(@_)
sub config {
  my $class = shift;
  $class = blessed $class || $class;

  if(my $ab_config = $class->runtime_prop)
  {
    my $key = shift;
    return $ab_config->{legacy}->{$key};
  }

  my $config = $class . '::ConfigData';
  eval "require $config";
  warn $@ if $@;

  return $config->config(@_);
}

# helper method to split flags based on the OS
sub split_flags {
  my ($class, $line) = @_;
  if( $^O eq 'MSWin32' ) {
    $class->split_flags_windows($line);
  } else {
    # $os eq 'Unix'
    $class->split_flags_unix($line);
  }
}

sub split_flags_unix {
  my ($class, $line) = @_;
  shellwords($line);
}

sub split_flags_windows {
  # NOTE a better approach would be to write a function that understands cmd.exe metacharacters.
  my ($class, $line) = @_;

  # Double the backslashes so that when they are unescaped by shellwords(),
  # they become a single backslash. This should be fine on Windows since
  # backslashes are not used to escape metacharacters in cmd.exe.
  $line =~ s,\\,\\\\,g;
  shellwords($line);
}

=head2 dynamic_libs

 my @dlls = Alien::MyLibrary->dynamic_libs;
 my($dll) = Alien::MyLibrary->dynamic_libs;

Returns a list of the dynamic library or shared object files for the
alien software.

=cut

sub dynamic_libs {
  my ($class) = @_;
  
  require FFI::CheckLib;
  
  if($class->install_type('system')) {

    my $name = $class->config('ffi_name');
    unless(defined $name) {
      $name = $class->config('name');
      # strip leading lib from things like libarchive or libffi
      $name =~ s/^lib//;
      # strip trailing version numbers
      $name =~ s/-[0-9\.]+$//;
    }
    
    return FFI::CheckLib::find_lib(lib => $name);
  
  } else {
  
    my $dir = $class->dist_dir;
    my $dynamic = File::Spec->catfile($class->dist_dir, 'dynamic');
    
    if(-d $dynamic)
    {
      return FFI::CheckLib::find_lib(
        lib        => '*',
        libpath    => $dynamic,
        systempath => [],
      );
    }

    return FFI::CheckLib::find_lib(
      lib        => '*',
      libpath    => $dir,
      systempath => [],
      recursive  => 1,
    );
  }
}

=head2 bin_dir

 my(@dir) = Alien::MyLibrary->bin_dir

Returns a list of directories with executables in them.  For a C<system>
install this will be an empty list.  For a C<share> install this will be
a directory under C<dist_dir> named C<bin> if it exists.  You may wish
to override the default behavior if you have executables or scripts that
get installed into non-standard locations.

Example usage:

 use Env qw( @PATH );
 
 unshft @PATH, Alien::MyLibrary->bin_dir;

=cut

sub bin_dir {
  my ($class) = @_;
  if($class->install_type('system'))
  {
    my $prop = $class->runtime_prop;
    return unless defined $prop;
    return unless defined $prop->{system_bin_dir};
    return ref $prop->{system_bin_dir} ? @{ $prop->{system_bin_dir} } : ($prop->{system_bin_dir});
  }
  else
  {
    my $dir = File::Spec->catfile($class->dist_dir, 'bin');
    return -d $dir ? ($dir) : ();
  }
}

=head2 alien_helper

 my $helpers = Alien::MyLibrary->alien_helper;

Returns a hash reference of helpers provided by the Alien module.
The keys are helper names and the values are code references.  The
code references will be executed at command time and the return value
will be interpolated into the command before execution.  The default
implementation returns an empty hash reference, and you are expected
to override the method to create your own helpers.

For use with commands specified in and L<alienfile> or in your C<Build.Pl>
when used with L<Alien::Base::ModuleBuild>.

Helpers allow users of your Alien module to use platform or environment 
determined logic to compute command names or arguments in your installer
logic.  Helpers allow you to do this without making your Alien module a
requirement when a build from source code is not necessary.

As a concrete example, consider L<Alien::gmake>, which provides the 
helper C<gmake>:

 package Alien::gmake;
 
 ...
 
 sub alien_helper {
   my($class) = @_;
   return {
     gmake => sub {
       # return the executable name for GNU make,
       # usually either make or gmake depending on
       # the platform and environment
       $class->exe;
     }
   },
 }

Now consider L<Alien::nasm>.  C<nasm> requires GNU Make to build from 
source code, but if the system C<nasm> package is installed we don't 
need it.  From the L<alienfile> of C<Alien::nasm>:

 use alienfile;
 
 plugin 'Probe::CommandLine' => (
   command => 'nasm',
   args    => ['-v'],
   match   => qr/NASM version/,
 );
 
 share {
   ...
   plugin 'Extract' => 'tar.gz';
   plugin 'Build::MSYS' => ();
   
   build [
     'sh configure --prefix=%{alien.install.prefix}',
     '%{gmake}',
     '%{gmake} install',
   ];
 };
 
 ...

=cut

sub alien_helper {
  {};
}

=head2 inline_auto_include

 my(@headers) = Alien::MyLibrary->inline_auto_include;

List of header files to automatically include in inline C and C++
code when using L<Inline::C> or L<Inline::CPP>.  This is provided
as a public interface primarily so that it can be overidden at run
time.  This can also be specified in your C<Build.PL> with 
L<Alien::Base::ModuleBuild> using the C<alien_inline_auto_include>
property.

=cut

sub inline_auto_include {
  my ($class) = @_;
  return [] unless $class->config('inline_auto_include');
  $class->config('inline_auto_include')
}

sub Inline {
  my ($class, $language) = @_;
  return if $language !~ /^(C|CPP)$/;
  my $config = {
    CCFLAGSEX    => $class->cflags,
    LIBS         => $class->libs,
  };
  
  if (@{ $class->inline_auto_include } > 0) {
    $config->{AUTO_INCLUDE} = join "\n", map { "#include \"$_\"" } @{ $class->inline_auto_include };
  }
  
  $config;
}

=head2 runtime_prop

 my $hashref = Alien::MyLibrary->runtime_prop;

Returns a hash reference of the runtime properties computed by L<Alien::Build> during its
install process.  If the L<Alien::Base> based L<Alien> was not built using L<Alien::Build>,
then this will return undef.

=cut

{
  my %alien_build_config_cache;

  sub runtime_prop
  {
    my($class) = @_;
  
    return $alien_build_config_cache{$class} if
      exists $alien_build_config_cache{$class};
  
    $alien_build_config_cache{$class} ||= do {
      my $dist = ref $class ? ref $class : $class;
      $dist =~ s/::/-/g;
      my $dist_dir = eval { File::ShareDir::dist_dir($dist) };
      return if $@;
      my $alien_json = File::Spec->catfile($dist_dir, '_alien', 'alien.json');
      return unless -r $alien_json;
      open my $fh, '<', $alien_json;
      my $json = do { local $/; <$fh> };
      close $fh;
      require JSON::PP;
      my $config = JSON::PP::decode_json($json);
      $config->{distdir} = $dist_dir;
      $config;
    };
  }
}

1;

__END__
__POD__

=head1 SUPPORT AND CONTRIBUTING

First check the L<Alien::Base::FAQ> for questions that have already been answered.

IRC: #native on irc.perl.org

L<(click for instant chatroom login)|http://chat.mibbit.com/#native@irc.perl.org> 

If you find a bug, please report it on the projects issue tracker on GitHub:

=over 4

=item L<https://github.com/Perl5-Alien/Alien-Base/issues>

=back

Development is discussed on the projects google groups.  This is also
a reasonable place to post a question if you don't want to open an issue
in GitHub.

=over 4

=item L<https://groups.google.com/forum/#!forum/perl5-alien>

=back

If you have implemented a new feature or fixed a bug, please open a pull 
request.

=over 4

=item L<https://github.com/Perl5-Alien/Alien-Base/pulls>

=back

=head1 SEE ALSO

=over 

=item * 

L<Alien::Build>

=item *

L<alienfile>

=item *

L<Alien>

=item *

L<Alien::Base::FAQ>

=back

=head1 AUTHOR

Original author: Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

Current maintainer: Graham Ollis E<lt>plicease@cpan.orgE<gt> and the L<Alien::Base> team

=head1 CONTRIBUTORS

=over 

=item David Mertens (run4flat)

=item Mark Nunberg (mordy, mnunberg)

=item Christian Walde (Mithaldu)

=item Brian Wightman (MidLifeXis)

=item Graham Ollis (plicease)

=item Zaki Mughal (zmughal)

=item mohawk2

=item Vikas N Kumar (vikasnkumar)

=item Flavio Poletti (polettix)

=item Salvador Fandiño (salva)

=item Gianni Ceccarelli (dakkar)

=item Pavel Shaydo (zwon, trinitum)

=item Kang-min Liu (劉康民, gugod)

=item Nicholas Shipp (nshp)

=back

Thanks also to

=over

=item Christian Walde (Mithaldu)

For productive conversations about component interoperablility.

=item kmx

For writing Alien::Tidyp from which I drew many of my initial ideas.

=item David Mertens (run4flat)

For productive conversations about implementation.

=item Mark Nunberg (mordy, mnunberg)

For graciously teaching me about rpath and dynamic loading,

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2017 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

