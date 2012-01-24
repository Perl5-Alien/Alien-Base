package Alien::Base::ModuleBuild;

use strict;
use warnings;

use parent 'Module::Build';

use Capture::Tiny 'capture_stderr';
use Sort::Versions;
use File::chdir;
use Sort::Versions;
use Carp;

use Alien::Base::ModuleBuild::Repository;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= 0;

## Extra parameters in $self (all (toplevel) should start with 'alien_')
# alien_name -- name of library 
# alien_temp_folder -- folder name or File::Temp object for download/build
# alien_share_folder -- full folder name for $self->{share_dir}
# alien_build_commands -- arrayref of commands for building
# alien_version_check -- command to execute to check if install/version
# alien_repository -- hash (or arrayref of hashes) of information about source repo on ftp
#   protocol -- ftp or http
#   host -- ftp server for source
#   folder -- ftp folder containing source
#   platform -- src or platform
#     pattern
#     files -- holder for found files (on ftp server)
#     versions -- holder for version=>file
#   connection  -- holder for Net::FTP-like object (needs cwd, ls, and get methods)
#   connection_class -- holder for class type (defaults to 'Net::FTP')

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  my @repos = 
    ( (ref $self->{alien_repository} || '') eq 'ARRAY')
      ? @{ $self->{alien_repository} }
      : $self->{alien_repository};

  # map repository constructs to A::B::MB::R objects
  @repos = 
    map { Alien::Base::ModuleBuild::Repository->new($_) } 
    @repos;

  $self->{alien_repository} = \@repos;

  return $self;
}

sub alien_main_procedure {
  my $self = shift;

  #TODO make this work for more that one repo
  my $repo = $self->{alien_repository}->[0];

  my $files = $repo->probe();

  my @ordered_files;
  if (ref $files eq 'HASH') {
    #hash structure is like {version => filename}
    @ordered_files = 
      map  { $files->{$_} } 
      sort { versioncmp($a,$b) }
      keys %$files;
  } else {
    @ordered_files = sort { versioncmp($a,$b) } @$files;
  }

  #TODO allow for specific version
  my $file = $ordered_files[-1];

  local $CWD = $self->alien_temp_folder;
  $repo->get_file($file);
}

sub alien_temp_folder {
  my $self = shift;

  return $self->{alien_temp_folder}
    if defined $self->{alien_temp_folder};

  my $tempdir = File::Temp->newdir();

  $self->{alien_temp_folder} = $tempdir;

  return $tempdir;
}

sub alien_share_folder {
  my $self = shift;

  return $self->{alien_share_folder}
    if defined $self->{alien_share_folder};

  my $location = do {
    # for share_dir install get full path to share_dir
    local $CWD = $self->base_dir();
    push @CWD, $self->{'share_dir'};
    "$CWD";    
  };

  return $location;
}

sub alien_check_installed_version {
  my $self = shift;
  my $name = $self->{alien_name};
  my $command = $self->{alien_version_check} || "pkg-config --modversion $name";

  my $version;
  my $err = capture_stderr {
    $version = `$command` || 0;
  };

  print "Command `$command` had stderr: $err" if ($Verbose and $err);

  return $version;
}

sub alien_interpolate {
  my $self = shift;
  my ($string) = @_;

  my $prefix = $self->alien_exec_prefix;
  my $share  = $self->alien_share_folder;

  # substitute:
  #   install location share_dir (placeholder: %s)
  $string =~ s/(?<!\%)\%s/$share/g;
  #   local exec prefix (ph: %p)
  $string =~ s/(?<!\%)\%p/$prefix/g;

  #remove escapes
  $string =~ s/\%(?=\%)//g;

  return $string;
}

###################
#  Build Methods  #
###################

sub alien_build {
  my $self = shift;

  my $commands = 
    $self->{alien_build_commands} 
    || [ '%pconfigure --prefix=%s', 'make', 'make install' ];

  local $CWD = $self->alien_temp_folder;

  foreach my $command (@$commands) {
    $command = $self->alien_interpolate($command);

    system( $command );
    if ($?) {
      print "External command ($command) failed!\n";
      return 0;
    }
  }

  return 1;
}

########################
#   Helper Functions   #
########################

sub alien_exec_prefix {
  if ( $^O eq 'MSWin32' ) {
    return '';
  } else {
    return './';
  }
}

1;

