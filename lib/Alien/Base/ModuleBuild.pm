package Alien::Base::ModuleBuild;

use strict;
use warnings;

our $VERSION = '0.005_02';
$VERSION = eval $VERSION;

use parent 'Module::Build';

use Capture::Tiny 0.17 qw/capture tee/;
use File::chdir;
use File::Spec;
use File::Basename qw/fileparse/;
use Carp;
no warnings;
use Archive::Extract;
use warnings;
use Sort::Versions;
use List::MoreUtils qw/uniq first_index/;
use ExtUtils::Installed;
use File::Copy qw/move/;

use Alien::Base::PkgConfig;
use Alien::Base::ModuleBuild::Cabinet;
use Alien::Base::ModuleBuild::Repository;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;
use Alien::Base::ModuleBuild::Repository::Local;

# setup protocol specific classes
# Alien:: author can override these defaults using alien_repository_class property
my %default_repository_class = (
  default => 'Alien::Base::ModuleBuild::Repository',
  http    => 'Alien::Base::ModuleBuild::Repository::HTTP',
  ftp     => 'Alien::Base::ModuleBuild::Repository::FTP',
  local   => 'Alien::Base::ModuleBuild::Repository::Local',
);

our $Verbose;
$Verbose = $ENV{ALIEN_VERBOSE} if defined $ENV{ALIEN_VERBOSE};

our $Force;
$Force = $ENV{ALIEN_FORCE} if defined $ENV{ALIEN_FORCE};

################
#  Parameters  #
################

## Extra parameters in A::B::MB objects (all (toplevel) should start with 'alien_')

# alien_name: name of library 
__PACKAGE__->add_property('alien_name');

# alien_temp_dir: folder name for download/build
__PACKAGE__->add_property( alien_temp_dir => '_alien' );

# alien_share_dir: folder name for the "install" of the library
# this is added (unshifted) to the @{share_dir->{dist}}  
# N.B. is reset during constructor to be full folder name 
__PACKAGE__->add_property('alien_share_dir' => '_share' );

# alien_selection_method: name of method for selecting file: (todo: newest, manual)
#   default is specified later, when this is undef (see alien_check_installed_version)
__PACKAGE__->add_property( alien_selection_method => 'newest' );

# alien_build_commands: arrayref of commands for building
__PACKAGE__->add_property( 
  alien_build_commands => 
  default => [ '%c --prefix=%s', 'make' ],
);

# alien_test_commands: arrayref of commands for testing the library
# note that this might be better tacked onto the build-time commands
__PACKAGE__->add_property( 
  alien_test_commands => 
  default => [ ],
);

# alien_build_commands: arrayref of commands for installing the library
__PACKAGE__->add_property( 
  alien_install_commands => 
  default => [ 'make install' ],
);

# alien_version_check: command to execute to check if install/version
__PACKAGE__->add_property( alien_version_check => Alien::Base::PkgConfig->pkg_config_command . ' --modversion %n' );

# pkgconfig-esque info, author provides these by hand for now, will parse .pc file eventually
__PACKAGE__->add_property( 'alien_provides_cflags' );
__PACKAGE__->add_property( 'alien_provides_libs' );

# alien_repository: hash (or arrayref of hashes) of information about source repo on ftp
#   |-- protocol: ftp or http
#   |-- protocol_class: holder for class type (defaults to 'Net::FTP' or 'HTTP::Tiny')
#   |-- host: ftp server for source
#   |-- location: ftp folder containing source, http addr to page with links
#   |-- pattern: qr regex matching acceptable files, if has capture group those are version numbers
#   |-- platform: src or platform, matching os_type M::B method
#   |
#   |-- (non-api) connection: holder for Net::FTP-like object (needs cwd, ls, and get methods)
__PACKAGE__->add_property( 'alien_repository'         => {} );
__PACKAGE__->add_property( 'alien_repository_default' => {} );
__PACKAGE__->add_property( 'alien_repository_class'   => {} );

# alien_isolate_dynamic
__PACKAGE__->add_property( 'alien_isolate_dynamic' => 0 );
__PACKAGE__->add_property( 'alien_autoconf_with_pic' => 1 );

# alien_inline_auto_include
__PACKAGE__->add_property( 'alien_inline_auto_include' => [] );

################
#  ConfigData  #
################

# working_directory: full path to the extracted source or binary of the library
# pkgconfig: hashref of A::B::PkgConfig objects created from .pc file found in working_directory
# install_type: either system or share
# version: version number installed or available
# Cflags: holder for cflags if manually specified
# Libs:   same but libs
# name: holder for name as needed by pkg-config
# finished_installing: set to true once ACTION_install is finished, this helps testing now and real checks later

############################
#  Initialization Methods  #
############################

sub new {
  my $class = shift;
  my %args = @_;

  # merge default and user-defined repository classes
  $args{alien_repository_class}{$_} ||= $default_repository_class{$_} 
    for keys %default_repository_class;

  my $self = $class->SUPER::new(%args);

  # setup additional temporary directories, and yes we have to add File::ShareDir manually
  $self->_add_prereq( 'requires', 'File::ShareDir', '1.00' );

  # this just gets passed from the Build.PL to the config so that it can
  # be used by the auto_include method
  $self->config_data( 'inline_auto_include' => $self->alien_inline_auto_include );

  if (grep /(?<!\%)\%c/, @{ $self->alien_build_commands }) {
    $self->config_data( 'autoconf' => 1 );
  }

  if ($^O eq 'MSWin32' && $self->config_data( 'autoconf')) {
    $self->_add_prereq( 'build_requires', 'Alien::MSYS', '0' );
    $self->config_data( 'msys' => 1 );
  } else {
    $self->config_data( 'msys' => 0 );
  }

  # force newest for all automated testing 
  #TODO (this probably should be checked for "input needed" rather than blindly assigned)
  if ($ENV{AUTOMATED_TESTING}) {
    $self->alien_selection_method('newest');
  }

  $self->config_data( 'finished_installing' => 0 );

  return $self;
}

sub alien_init_temp_dir {
  my $self = shift;
  my $temp_dir = $self->alien_temp_dir;
  my $share_dir = $self->alien_share_dir;

  # make sure we are in base_dir
  local $CWD = $self->base_dir;

  unless ( -d $temp_dir ) {
    mkdir $temp_dir or croak "Could not create temporary directory $temp_dir";
  }
  $self->add_to_cleanup( $temp_dir );

  unless ( -d $share_dir ) {
    mkdir $share_dir or croak "Could not create temporary directory $share_dir";
  }
  $self->add_to_cleanup( $share_dir );

  # add share dir to share dir list
  my $share_dirs = $self->share_dir;
  unshift @{ $share_dirs->{dist} }, $share_dir;
  $self->share_dir( $share_dirs );
  {
    local $CWD = $share_dir;
    open my $fh, '>', 'README' or die "Could not open README for writing (in directory $share_dir)\n";
    print $fh <<'END';
This README file is autogenerated by Alien::Base. 

Currently it exists for testing purposes, but it might eventually contain information about the file(s) installed.
END
  }
}

####################
#  ACTION methods  #
####################

sub ACTION_code {
  my $self = shift;
  $self->notes( 'alien_blib_scheme' => $self->alien_detect_blib_scheme );

  # PLEASE NOTE, BOTH BRANCHES CALL SUPER::ACTION_code !!!!!!!
  if ( $self->notes('ACTION_alien_completed') ) {

    $self->SUPER::ACTION_code;

  } else {

    $self->depends_on('alien_code');
    $self->SUPER::ACTION_code;

    # copy the compiled files into blib if running under blib scheme
    $self->depends_on('alien_install') if $self->notes('alien_blib_scheme');
  }
}

sub ACTION_alien_code {
  my $self = shift;
  local $| = 1; # don't buffer stdout

  $self->alien_init_temp_dir;

  $self->config_data( name => $self->alien_name );

  my $version;
  $version = $self->alien_check_installed_version
    unless $Force;

  if ($version) {
    $self->config_data( install_type => 'system' );
    $self->config_data( version => $version );
    return;
  }

  my @repos = $self->alien_create_repositories;

  my $cabinet = Alien::Base::ModuleBuild::Cabinet->new;

  foreach my $repo (@repos) {
    $cabinet->add_files( $repo->probe() );
  }

  $cabinet->sort_files;

  {
    local $CWD = $self->alien_temp_dir;

    my $file = $cabinet->files->[0];
    $version = $file->version;
    $self->config_data( alien_version => $version ); # Temporary setting, may be overridden later

    print "Downloading File: " . $file->filename . " ... ";
    my $filename = $file->get;
    croak "Error downloading file" unless $filename;
    print "Done\n";

    print "Extracting Archive ... ";
    my $ae = Archive::Extract->new( archive => $filename );
    $ae->extract;
    print "Done\n";

    my $extract_path = _catdir($ae->extract_path);
    $self->config_data( working_directory => $extract_path );
    $CWD = $extract_path;

    if ( $file->platform eq 'src' ) {
      print "Building library ... ";
      unless ($self->alien_do_commands('build')) {
        print "Failed\n";
        croak "Build not completed";
      }
    }

    print "Done\n";

  }

  $self->config_data( install_type => 'share' );

  my $pc = $self->alien_load_pkgconfig;
  my $pc_version = (
    $pc->{$self->alien_name} || $pc->{_manual}
  )->keyword('Version');

  if (! $version and ! $pc_version) {
    carp "Library looks like it installed, but no version was determined";
    $self->config_data( version => 0 );    
    return
  }

  if ( $version and $pc_version and versioncmp($version, $pc_version)) {
    carp "Version information extracted from the file name and pkgconfig data disagree";
  } 

  $self->config_data( version => $pc_version || $version );

  # prevent building multiple times (on M::B::dispatch)
  $self->notes( 'ACTION_alien_completed' => 1 );

  return;
}

sub ACTION_test {
  my $self = shift;
  $self->SUPER::ACTION_test;

  local $CWD = $self->config_data( 'working_directory' );
  print "Testing library (if applicable) ... ";
  $self->alien_do_commands('test') or die "Failed\n";
  print "Done\n";
}

sub ACTION_install {
  my $self = shift;
  $self->SUPER::ACTION_install;
  $self->depends_on('alien_install');
}

sub ACTION_alien_install {
  my $self = shift;

  local $| = 1; # don't buffer stdout

  return if $self->config_data( 'install_type' ) eq 'system';

  my $destdir = $self->destdir;

  {
    my $target = $self->alien_library_destination;
    # prefix the target directory with $destdir so that package builds
    # can install into a fake root
    $target = File::Spec->catdir($destdir, $target) if defined $destdir;
    local $CWD = $target;

    # The only form of introspection that exists is to see that the README file
    # which was placed in the share_dir (default _share) exists where we expect 
    # after installation.
    unless ( -e 'README' ) {
      die "share_dir mismatch detected ($target)\n"
    }
  }

  {
    local $CWD = $self->config_data( 'working_directory' );
    local $ENV{DESTDIR} = $ENV{DESTDIR};
    $ENV{DESTDIR} = $destdir if defined $destdir;
    print "Installing library to $CWD ... ";
    $self->alien_do_commands('install') or die "Failed\n";
    print "Done\n";
  }
  
  if ( $self->alien_isolate_dynamic ) {
    my $target = $self->alien_library_destination;
    # prefix the target directory with $destdir so that package builds
    # can install into a fake root
    $target = File::Spec->catdir($destdir, $target) if defined $destdir;
    local $CWD = $target;
    print "Isolating dynamic libraries ... ";
    mkdir 'dynamic' unless -d 'dynamic';
    foreach my $dir (qw( bin lib )) {
      next unless -d $dir;
      opendir(my $dh, $dir);
      my @dlls = grep { /\.so/ || /\.(dylib|la|dll|dll\.a)$/ } grep !/^\./, readdir $dh;
      closedir $dh;
      foreach my $dll (@dlls) {
        my $from = File::Spec->catfile($dir, $dll);
        my $to   = File::Spec->catfile('dynamic', $dll);
        unlink $to if -e $to;
        move($from, $to);
      }
    }
    print "Done\n";
  }

  # refresh metadata after library installation
  $self->alien_refresh_manual_pkgconfig( $self->alien_library_destination );
  $self->config_data( 'finished_installing' => 1 );

  # to refresh config_data
  $self->SUPER::ACTION_config_data;

  if ( $self->notes( 'alien_blib_scheme') ) {
    # reinstall config_data to blib
    $self->process_files_by_extension('pm');

  } else {
    # reinstall config_data
    $self->SUPER::ACTION_install;

    # refresh the packlist
    $self->alien_refresh_packlist( $self->alien_library_destination );
  }
}

#######################
#  Pre-build Methods  #
#######################

sub alien_check_installed_version {
  my $self = shift;
  my $command = $self->alien_version_check;

  my %result = $self->do_system($command, {verbose => 0});
  my $version = $result{stdout} || 0;

  return $version;
}

sub alien_create_repositories {
  my $self = shift;

  ## get repository specs
  my $repo_default = $self->alien_repository_default;
  my $repo_specs = $self->alien_repository;

  # upconvert to arrayref if a single hashref is passed
  if (ref $repo_specs eq 'HASH') {
    $repo_specs = [ $repo_specs ];
  }

  my @repos;
  foreach my $repo ( @$repo_specs ) {
    #merge defaults into spec
    foreach my $key ( keys %$repo_default ) {
      next if defined $repo->{$key};
      $repo->{$key} = $repo_default->{$key};
    }

    $repo->{platform} = 'src' unless defined $repo->{platform};
    my $protocol = $repo->{protocol} || 'default';

    push @repos, $self->alien_repository_class($protocol)->new( $repo );
  }

  # check validation, including c compiler for src type
  @repos = 
    grep { $self->alien_validate_repo($_) }
    @repos;

  unless (@repos) {
    croak "No valid repositories available";
  }

  return @repos;

}

sub alien_validate_repo {
  my $self = shift;
  my ($repo) = @_;
  my $platform = $repo->{platform};

  # return true if platform is undefined
  return 1 unless defined $platform;

  # if $valid is src, check for c compiler
  if ($platform eq 'src') {
    return $self->have_c_compiler;
  }

  # $valid is a string (OS) to match against
  return $self->os_type eq $platform;
}

sub alien_library_destination {
  my $self = shift;

  # send the library into the blib if running under the blib scheme
  my $lib_dir = 
    $self->notes('alien_blib_scheme')
    ? File::Spec->catdir( $self->base_dir, $self->blib, 'lib' )
    : $self->install_destination('lib');

  my $dist_name = $self->dist_name;
  my $dest = _catdir( $lib_dir, qw/auto share dist/, $dist_name );
  return $dest;
}

# CPAN testers often run tests without installing modules, but rather add
# blib dirs to @INC, this is a problem, so here we try to deal with it
sub alien_detect_blib_scheme {
  my $self = shift;

  return $ENV{ALIEN_BLIB} if defined $ENV{ALIEN_BLIB};

  # check to see if Alien::Base::ModuleBuild is running from blib.
  # if so it is likely that this is the blib scheme

  (undef, my $dir, undef) = File::Spec->splitpath( __FILE__ );
  my @dirs = File::Spec->splitdir($dir);

  my $index = first_index { $_ eq 'blib' } @dirs;
  return 0 if $index == -1;

  if ( $dirs[$index+1] eq 'lib' ) {
    print qq{'blib' scheme is detected. Setting ALIEN_BLIB=1. If this has been done in error, please set ALIEN_BLIB and restart build process to disambiguate.\n};
    return 1;
  }

  carp q{'blib' scheme is suspected, but uncertain. Please set ALIEN_BLIB and restart build process to disambiguate. Setting ALIEN_BLIB=1 for now.};
  return 1;
}

###################
#  Build Methods  #
###################

sub _msys_do_system {
  my $self = shift;
  my $command = shift;
  
  if ($self->config_data( 'msys' )) {
    require Alien::MSYS;
    return Alien::MSYS::msys(sub { $self->do_system( $command ) });
  }
  
  $self->do_system( $command );
}

sub alien_do_commands {
  my $self = shift;
  my $phase = shift;

  my $attr = "alien_${phase}_commands";
  my $commands = $self->$attr();

  foreach my $command (@$commands) {

    my %result = $self->_msys_do_system( $command );
    unless ($result{success}) {
      carp "External command ($result{command}) failed! Error: $?\n";
      return 0;
    }
  }

  return 1;
}

# wrapper for M::B::do_system which interpolates alien_ vars first
# futher it either captures or tees depending on the value of $Verbose
sub do_system {
  my $self = shift;
  my $opts = ref $_[-1] ? pop : { verbose => 1 };

  my $verbose = $Verbose || $opts->{verbose};

  # prevent build process from cwd-ing from underneath us
  local $CWD;
  my $initial_cwd = $CWD;

  my @args = map { $self->alien_interpolate($_) } @_;

  my ($out, $err, $success) = 
    $verbose
    ? tee     { $self->SUPER::do_system(@args) }
    : capture { $self->SUPER::do_system(@args) }
  ;

  my %return = (
    stdout => $out,
    stderr => $err,
    success => $success,
    command => join(' ', @args),
  );

  # restore wd
  $CWD = $initial_cwd;

  return wantarray ? %return : $return{success};
}

sub alien_interpolate {
  my $self = shift;
  my ($string) = @_;

  my $prefix = $self->alien_exec_prefix;
  my $configure = $self->alien_configure;
  my $share  = $self->alien_library_destination;
  my $name   = $self->alien_name || '';

  # substitute:
  #   install location share_dir (placeholder: %s)
  $string =~ s/(?<!\%)\%s/$share/g;
  #   local exec prefix (ph: %p)
  $string =~ s/(?<!\%)\%p/$prefix/g;
  #   correct incantation for configure on platform
  $string =~ s/(?<!\%)\%c/$configure/g;
  #   library name (ph: %n)
  $string =~ s/(?<!\%)\%n/$name/g;
  #   current interpreter ($^X) (ph: %x)
  my $perl = $self->perl;
  $string =~ s/(?<!\%)\%x/$perl/g;

  # Version, but only if needed.  Complain if needed and not yet
  # stored.
  if ($string =~ /(?<!\%)\%v/) {
    my $version = $self->config_data( 'alien_version' );
    if ( ! defined( $version ) ) {
      carp "Version substution requested but unable to identify";
    } else {
      $string =~ s/(?<!\%)\%v/$version/g;
    }
  }

  #remove escapes (%%)
  $string =~ s/\%(?=\%)//g;

  return $string;
}

sub alien_exec_prefix {
  my $self = shift;
  if ( $self->is_windowsish ) {
    return '';
  } else {
    return './';
  }
}

sub alien_configure {
  my $self = shift;
  my $configure;
  if ($self->config_data( 'msys' )) {
    $configure = 'sh configure';
  } else {
    $configure = './configure';
  }
  if ($self->alien_autoconf_with_pic) {
    $configure .= ' --with-pic';
  }
  $configure;
}

########################
#  Post-Build Methods  #
########################

sub alien_load_pkgconfig {
  my $self = shift;

  my $dir = _catdir($self->config_data( 'working_directory' ));
  my $pc_files = $self->rscan_dir( $dir, qr/\.pc$/ );

  my %pc_objects = map { 
    my $pc = Alien::Base::PkgConfig->new($_);
    $pc->make_abstract( pcfiledir => $dir );
    ($pc->{package}, $pc)
  } @$pc_files;

  $pc_objects{_manual} = $self->alien_generate_manual_pkgconfig($dir)
    or croak "Could not autogenerate pkgconfig information";

  $self->config_data( pkgconfig => \%pc_objects );
  return \%pc_objects;
}

sub alien_refresh_manual_pkgconfig {
  my $self = shift;
  my ($dir) = @_;

  my $pc_objects = $self->config_data( 'pkgconfig' );
  $pc_objects->{_manual} = $self->alien_generate_manual_pkgconfig($dir)
    or croak "Could not autogenerate pkgconfig information";
  
  $self->config_data( pkgconfig => $pc_objects );

  return 1;
}

sub alien_generate_manual_pkgconfig {
  my $self = shift;
  my ($dir) = _catdir(shift);

  my $paths = $self->alien_find_lib_paths($dir);

  my @L = 
    map { "-L$_" }
    map { _catdir( '${pcfiledir}', $_ ) }
    @{$paths->{lib}};

  my $provides_libs = $self->alien_provides_libs;

  #if no provides_libs then generate -l list from found files
  unless ($provides_libs) {
    my @files = map { "-l$_" } @{$paths->{lib_files}};
    $provides_libs = join( ' ', @files );
  } 

  my $libs = join( ' ', @L, $provides_libs );

  my @I = 
    map { "-I$_" }
    map { _catdir( '${pcfiledir}', $_ ) }
    @{$paths->{inc}};

  my $provides_cflags = $self->alien_provides_cflags;
  push @I, $provides_cflags if $provides_cflags;
  my $cflags = join( ' ', @I );

  my $manual_pc = Alien::Base::PkgConfig->new({
    package  => $self->alien_name,
    vars     => {
      pcfiledir => $dir,
    },
    keywords => {
      Cflags  => $cflags || '',
      Libs    => $libs || '',
      Version => '',
    },
  });

  return $manual_pc;
}

sub _alien_file_pattern_dynamic {
  my $self = shift;
  my $ext = $self->config('so'); #platform specific .so extension
  return qr/\.[\d.]*(?<=\.)$ext[\d.]*(?<!\.)|(\.h|$ext)$/;
};

sub _alien_file_pattern_static {
  my $self = shift;
  my $ext = quotemeta $self->config('lib_ext');
  return qr/(\.h|$ext)$/;
}

sub alien_find_lib_paths {
  my $self = shift;
  my ($dir) = @_;

  my $libs = $self->alien_provides_libs;
  my @libs;
  @libs = grep { s/^-l// } split /\s+/, $libs if $libs;

  my (@lib_files, @lib_paths, @inc_paths);

  foreach my $file_pattern ($self->_alien_file_pattern_static, $self->_alien_file_pattern_dynamic) {

    my @files =     
      map { File::Spec->abs2rel( $_, $dir ) }  # make relative to $dir
      grep { ! -d }
      @{ $self->_rscan_destdir( $dir, $file_pattern ) };

    for (@files) {

      my ($file, $path, $ext) = fileparse( $_, $file_pattern );
      next unless $ext; # just in case

      $path = File::Spec->catdir($path); # remove trailing /

      if ($ext eq '.h') {
        push @inc_paths, $path;
        next;
      }

      $file =~ s/^lib//;
      
      if (@libs) {
        next unless grep { $file eq $_ } @libs;
      }
      
      $DB::single = 1;
      
      next if grep { $file eq $_ } @lib_files;

      push @lib_files, $file;
      push @lib_paths, $path;
    }
  }

  @lib_files = uniq @lib_files;
  @lib_files = sort @lib_files;

  @lib_paths = uniq @lib_paths;
  @inc_paths = uniq @inc_paths;

  return { lib => \@lib_paths, inc => \@inc_paths, lib_files => \@lib_files };
}

sub alien_refresh_packlist {
  my $self = shift;
  my $dir = shift || croak "Must specify a directory to include in packlist";

  return unless $self->create_packlist;

  my %installed_args;
  $installed_args{extra_libs} = [map { File::Spec->catdir($self->destdir, $_) } @INC]
    if defined $self->destdir;

  my $inst = ExtUtils::Installed->new( %installed_args );
  my $packlist = $inst->packlist( $self->module_name );
  print "Using " .  $packlist->packlist_file . "\n";

  my $changed = 0;
  my $files = $self->_rscan_destdir($dir);
  # This is kind of strange, but MB puts the destdir paths in the
  # packfile, when arguably it should not.  Usually you will want 
  # to turn off packlists when you you are building an rpm anyway,
  # but for the sake of maximum compat with MB we add the destdir
  # back in after _rscan_destdir has stripped it out.
  $files = [ map { File::Spec->catdir($self->destdir, $_) } @$files ]
    if defined $self->destdir;
  for my $file (@$files) {
    next if $packlist->{$file};
    print "Adding $file to packlist\n"; 
    $changed++;
    $packlist->{$file}++;
  };

  $packlist->write if $changed;
}

sub _rscan_destdir {
  my($self, $dir, $pattern) = @_;
  my $destdir = $self->destdir;
  $dir = _catdir($destdir, $dir) if defined $destdir;
  my $files = $self->rscan_dir($dir, $pattern);
  $files = [ map { s/^$destdir//; $_ } @$files ] if defined $destdir;
  $files;
}

# File::Spec uses \ as the file separator on MSWin32, which makes sense
# since it is the default "native" file separator, but in practice / is
# supported everywhere that matters and is significantly less problematic
# in a number of common use cases (e.g. shell quoting).  This is a short
# cut _catdir for this rather common pattern where you want catdir with
# / as the file separator on Windows.
sub _catdir {
  my $dir = File::Spec->catdir(@_);
  $dir =~ s{\\}{/}g if $^O eq 'MSWin32';
  $dir;
}

1;

__END__
__POD__

=head1 NAME

Alien::Base::ModuleBuild - A Module::Build subclass for building Alien:: modules and their libraries

=head1 SYNOPSIS

In your Build.PL:

 use Alien::Base::ModuleBuild;
 
 my $builder = Alien::Base::Module::Build->new(
   module_name => 'Alien::MyLibrary',
   
   configure_requires => {
     'Alien::Base' =>   '0.005',
     'Module::Build' => '0.28'
   },
   requires => {
     'Alien::Base' => '0.005',
   },
   
   alien_name => 'mylibrary', # the pkg-config name if you want
                              # to use pkg-config to discover
                              # system version of the mylibrary
   
   alien_repository => {
     protocol => 'http',
     host     => 'myhost.org',
     location => '/path/to/tarballs',
     pattern  => qr{^mylibrary-([0-9\.]+)\.tar\.gz$},
   },
   
   # this is the default:
   alien_build_commands => [
     "%c --prefix=%s", # %c is a platform independent version of ./configure
     "make",
   ],
   
   # this is the default for install:
   alien_install_commands => [
     "make install",
   ],
   
   alien_isolate_dynamic => 1,
 );

=head1 DESCRIPTION

This is a subclass of L<Module::Build>, that with L<Alien::Base> allows
for easy creation of Alien distributions.  This module is used during the
build step of your distribution.  When properly configured it will

=over 4

=item use pkg-config to find and use the system version of the library

=item download, build and install the library if the system does not provide it

=back

=head1 GUIDE TO DOCUMENTATION

The documentation for C<Module::Build> is broken up into sections:
 
=over

=item General Usage (L<Module::Build>)
 
This is the landing document for L<Alien::Base::ModuleBuild>'s parent class.
It describes basic usage and background information.
Its main purpose is to assist the user who wants to learn how to invoke 
and control C<Module::Build> scripts at the command line.

It also lists the extra documentation for its use. Users and authors of Alien:: 
modules should familiarize themselves with these documents. L<Module::Build::API>
is of particular importance to authors. 
 
=item Alien-Specific Usage (L<Alien::Base::ModuleBuild>)
 
This is the document you are currently reading.
 
=item Authoring Reference (L<Alien::Base::Authoring>)
 
This document describes the structure and organization of 
C<Alien::Base> based projects, beyond that contained in
C<Module::Build::Authoring>, and the relevant concepts needed by authors who are
writing F<Build.PL> scripts for a distribution or controlling
C<Alien::Base::ModuleBuild> processes programmatically.

Note that as it contains information both for the build and use phases of 
L<Alien::Base> projects, it is located in the upper namespace.
 
=item API Reference (L<Alien::Base::ModuleBuild::API>)
 
This is a reference to the C<Alien::Base::ModuleBuild> API beyond that contained
in C<Module::Build::API>.
 
=back

=head1 AUTHOR

Joel Berger <joel.a.berger@gmail.com>

=head1 SEE ALSO

=over

=item * 

L<Module::Build>

=item *

L<Alien>

=item *

L<Alien::Base>

=back

=head1 SOURCE REPOSITORY

L<http://github.com/Perl5-Alien/Alien-Base>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2014 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

