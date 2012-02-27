package Alien::Base::ModuleBuild;

use strict;
use warnings;

use parent 'Module::Build';

use Capture::Tiny qw/capture_stderr capture_merged/;
use File::chdir;
use Carp;
use Archive::Extract;

use Alien::Base::ModuleBuild::Repository;
use Alien::Base::ModuleBuild::Cabinet;

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
#   |-- [platform]*: hashref of above keys for specific case (overrides defaults)
#   |
#   |-- (non-api) connection: holder for Net::FTP-like object (needs cwd, ls, and get methods)

################
#  ConfigData  #
################

# build_share_dir: full path to the shared directory specified in alien_share_dir

############################
#  Initialization Methods  #
############################

sub new {
  my $class = shift;
  my %args = @_;

  my $install_dir = $args{alien_share_dir} || '_install';
  my $cleanup_install_dir = 0;

  # if does not exist, create AND mark for add_to_cleanup
  unless ( -d $install_dir ) {
    mkdir $install_dir;
    $cleanup_install_dir = 1;
  }

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

  # add_to_cleanup if "new" had to create the folder
  $self->add_to_cleanup( $install_dir ) if $cleanup_install_dir;

  # store full path to alien_share_dir, used in interpolate
  $self->config_data( 
    build_share_dir => do {
      local $CWD = $self->base_dir();
      push @CWD, $install_dir;
      "$CWD"; 
    }   
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

  ## build repository objects
  my $repo_property = $self->{properties}{alien_repository};

  my $base_repo = Alien::Base::ModuleBuild::Repository->new(
    protocol       => delete $repo_property->{protocol},
    protocol_class => delete $repo_property->{protocol_class},
    host           => delete $repo_property->{host},
    location       => delete $repo_property->{location},
    pattern        => delete $repo_property->{pattern},
    platform       => delete $repo_property->{platform} || 'src',
  );

  my @platforms = keys %$repo_property;

  # map repository constructs to A::B::MB::R objects
  my @repos;
  if ( @platforms ) {
    # if plaform specifics exist, use base to build repos
    push @repos, 
      map { $base_repo->new( platform => $_, %{$repo_property->{$_}} ) } 
      @platforms;
  } else {
    push @repos, $base_repo;
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

  # make sure we are in base_dir
  local $CWD = $self->base_dir;

  unless ( -d $dir_name ) {
    mkdir $dir_name or croak "Could not create temporary directory $dir_name";
  }

  $self->add_to_cleanup( $dir_name );
}

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
    $command = $self->alien_interpolate($command);

    system( $command );
    if ($?) {
      print "External command ($command) failed! Error: $?\n";
      return 0;
    }
  }

  return 1;
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

1;

