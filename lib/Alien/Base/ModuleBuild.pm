package Alien::Base::ModuleBuild;

use strict;
use warnings;

use parent 'Module::Build';

use Capture::Tiny 'capture_stderr';
use Sort::Versions;
use File::chdir;
use Carp;
use Archive::Extract;

use Alien::Base::ModuleBuild::Repository;
use Alien::Base::ModuleBuild::Cabinet;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= 0;

## Extra parameters in A::B::MB objects (all (toplevel) should start with 'alien_')

# alien_name: name of library 
__PACKAGE__->add_property('alien_name');

# alien_temp_dir: folder name for download/build
__PACKAGE__->add_property( alien_temp_dir => '_alien' );

# alien_selection_method: name of method for selecting file: (todo: newest, manual)
#   default is specified later, when this is undef (see alien_check_installed_version)
__PACKAGE__->add_property( alien_selection_method => 'newest' );

# alien_build_commands: arrayref of commands for building
__PACKAGE__->add_property( 
  alien_build_commands => 
  default => [ '%pconfigure --prefix=%s', 'make', 'make install' ],
);

# alien_version_check: command to execute to check if install/version
__PACKAGE__->add_property( 'alien_version_check' );

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

# (non-api, set share_dir) alien_share_dir: full folder name for $self->{share_dir}
__PACKAGE__->add_property('alien_share_dir');


############################
#  Initialization Methods  #
############################

sub new {
  my $class = shift;
  my %args = @_;

  # initialize M::B property share_dir 
  $args{'share_dir'} = 'share' unless defined $args{'share_dir'};

  my $self = $class->SUPER::new(%args);

  # set alien_share_dir
  $self->alien_share_dir( do {
    my $share_dir = $self->{properties}{share_dir}{dist}[0];
    # for share_dir install get full path to share_dir
    local $CWD = $self->base_dir();
    # mkdir $share_dir unless ( -d $share_dir );
    push @CWD, $share_dir;
    "$CWD";    
  } );

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
    my $filename = $file->get;

    my $ae = Archive::Extract->new( archive => $filename );
    $ae->extract;
    $CWD = $ae->extract_path;

    $self->alien_build;
  }

}

#######################
#  Pre-build Methods  #
#######################

sub alien_check_installed_version {
  my $self = shift;
  my $name = $self->alien_name;
  my $command = $self->alien_version_check || "pkg-config --modversion $name";

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
  my $share  = $self->alien_share_dir;

  # substitute:
  #   install location share_dir (placeholder: %s)
  $string =~ s/(?<!\%)\%s/$share/g;
  #   local exec prefix (ph: %p)
  $string =~ s/(?<!\%)\%p/$prefix/g;

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

