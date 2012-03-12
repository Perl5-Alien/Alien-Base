package Alien::Base::ModuleBuild;

use strict;
use warnings;

use parent 'Module::Build';

use Capture::Tiny qw/capture_stderr capture_merged/;
use File::chdir;
use File::Spec;
use Carp;
use Archive::Extract;

use Alien::Base::PkgConfig;
use Alien::Base::ModuleBuild::Cabinet;
use Alien::Base::ModuleBuild::Repository;

use Alien::Base::ModuleBuild::Repository::HTTP;
use Alien::Base::ModuleBuild::Repository::FTP;
use Alien::Base::ModuleBuild::Repository::Test;
use Alien::Base::ModuleBuild::Repository::Local;

# setup protocol specific classes
# Alien:: author can override these defaults using alien_repository_class property
my %default_repository_class = (
  default => 'Alien::Base::ModuleBuild::Repository',
  http    => 'Alien::Base::ModuleBuild::Repository::HTTP',
  ftp     => 'Alien::Base::ModuleBuild::Repository::FTP',
  test    => 'Alien::Base::ModuleBuild::Repository::Test',
  local   => 'Alien::Base::ModuleBuild::Repository::Local',
);

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= $ENV{ALIEN_VERBOSE};

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
__PACKAGE__->add_property('alien_share_dir'); # default => '_install'

# alien_selection_method: name of method for selecting file: (todo: newest, manual)
#   default is specified later, when this is undef (see alien_check_installed_version)
__PACKAGE__->add_property( alien_selection_method => 'newest' );

# alien_build_commands: arrayref of commands for building
__PACKAGE__->add_property( 
  alien_build_commands => 
  default => [ '%pconfigure --prefix=%s', 'make', 'make install' ],
);

# alien_version_check: command to execute to check if install/version
__PACKAGE__->add_property( alien_version_check => 'pkg-config --modversion %n' );

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


################
#  ConfigData  #
################

# build_share_dir: full path to the shared directory specified in alien_share_dir
# pkgconfig: hashref of A::B::PkgConfig objects created from .pc file found in build_share_dir

############################
#  Initialization Methods  #
############################

sub new {
  my $class = shift;
  my %args = @_;

  my $install_dir = ($args{alien_share_dir} ||= '_install');

  # merge default and user-defined repository classes
  $args{alien_repository_class}{$_} ||= $default_repository_class{$_} 
    for keys %default_repository_class;

  # initialize M::B property share_dir 
  if (! defined $args{share_dir}) {
    # no share_dir property
    $args{share_dir} = $install_dir;
  } elsif (! ref $args{share_dir}) {
    # share_dir is a scalar, meaning dist
    $args{share_dir} = { dist => [$install_dir, $args{share_dir}] };
  } elsif (! ref $args{share_dir}{dist}) {
    # share_dir is like {dist => scalar}, so upconvert to arrayref
    $args{share_dir} = { dist => [$install_dir, $args{share_dir}{dist}] };
  } else {
    # share_dir is like {dist => [...]}, so unshift
    unshift @{$args{share_dir}{dist}}, $install_dir;
  }

  my $self = $class->SUPER::new(%args);

  # store full path to alien_share_dir, used in interpolate
  $self->config_data( 
    build_share_dir => File::Spec->catdir( $self->base_dir(), $install_dir )
  );

  # force newest for all automated testing 
  #TODO (this probably should be checked for "input needed" rather than blindly assigned)
  if ($ENV{AUTOMATED_TESTING}) {
    $self->alien_selection_method('newest');
  } 

  return $self;
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

sub alien_init_temp_dir {
  my $self = shift;
  my $dir_name = $self->alien_temp_dir;
  my $install_dir = $self->config_data('build_share_dir');

  # make sure we are in base_dir
  local $CWD = $self->base_dir;

  unless ( -d $dir_name ) {
    mkdir $dir_name or croak "Could not create temporary directory $dir_name";
  }
  $self->add_to_cleanup( $dir_name );

  # if install_dir does not exist, create AND mark for add_to_cleanup
  unless ( -d $install_dir ) {
    mkdir $install_dir;
    $self->add_to_cleanup( $install_dir );
  }
}

#TODO this method not used yet
sub alien_init_configdata {
  my $self = shift;

  my $cflags = $self->alien_provides_cflags;
  $self->config_data( cflags => $cflags );

  my $libs   = $self->alien_provides_libs;
  $self->config_data( libs   => $libs   );
}

####################
#  ACTION methods  #
####################

sub ACTION_code {
  my $self = shift;
  $self->depends_on('alien');
  $self->SUPER::ACTION_code;
}

sub ACTION_alien {
  my $self = shift;

  $self->alien_init_temp_dir;
  my @repos = $self->alien_create_repositories;

  my $cabinet = Alien::Base::ModuleBuild::Cabinet->new;

  foreach my $repo (@repos) {
    $cabinet->add_files( $repo->probe() );
  }

  $cabinet->sort_files;

  {
    local $CWD = $self->alien_temp_dir;

    my $file = $cabinet->files->[0];

    print "Downloading File: " . $file->filename . " ... ";
    my $filename = $file->get;
    print "Done\n";

    print "Extracting Archive ... ";
    my $ae = Archive::Extract->new( archive => $filename );
    $ae->extract;
    $CWD = $ae->extract_path;
    print "Done\n";

    print "Building library ... ";
    #TODO capture and log?
    my $build = sub { $self->alien_build };
    my $log;
    if ($Verbose) {
      $build->();
    } else {
      $log = capture_merged { $build->() };
    }
    print "Done\n";

  }

  $self->alien_load_pkgconfig;
}

#######################
#  Pre-build Methods  #
#######################

sub alien_check_installed_version {
  my $self = shift;
  my $command = $self->alien_version_check;

  $command = $self->alien_interpolate($command);

  my $version;
  my $err = capture_stderr {
    $version = `$command` || 0;
  };

  print "Command `$command` had stderr: $err" if ($Verbose and $err);

  return $version;
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

###################
#  Build Methods  #
###################

sub alien_build {
  my $self = shift;

  my $commands = $self->alien_build_commands;

  foreach my $command (@$commands) {
    my $success = $self->do_system( $command );
    unless ($success) {
      print "External command ($command) failed! Error: $?\n";
      return 0;
    }
  }

  return 1;
}

# wrapper for M::B::do_system which interpolates alien_ vars first
sub do_system {
  my $self = shift;
  my @args = map { $self->alien_interpolate($_) } @_;
  return $self->SUPER::do_system(@args);
}

sub alien_interpolate {
  my $self = shift;
  my ($string) = @_;

  my $prefix = $self->alien_exec_prefix;
  my $share  = $self->config_data('build_share_dir');
  my $name   = $self->alien_name;

  # substitute:
  #   install location share_dir (placeholder: %s)
  $string =~ s/(?<!\%)\%s/$share/g;
  #   local exec prefix (ph: %p)
  $string =~ s/(?<!\%)\%p/$prefix/g;
  #   library name (ph: %n)
  $string =~ s/(?<!\%)\%n/$name/g;

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

########################
#  Post-Build Methods  #
########################

sub alien_load_pkgconfig {
  my $self = shift;

  my $dir = $self->config_data('build_share_dir');
  my $pc_files = $self->rscan_dir( $dir, qr/\.pc$/ );

  return unless @$pc_files;  

  my %pc_objects = map { 
    my $pc = Alien::Base::PkgConfig->new($_);
    $pc->make_abstract( alien_dist_dir => $dir );
    ($pc->{package}, $pc)
  } @$pc_files;

  $self->config_data( pkgconfig => \%pc_objects);
}

1;

