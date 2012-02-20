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

## Extra parameters in $self (all (toplevel) should start with 'alien_')
# alien_name: name of library 
# alien_temp_folder: folder name or File::Temp object for download/build
# alien_selection_method: name of method for selecting file: (todo: newest, manual)
# alien_build_commands: arrayref of commands for building
# alien_version_check: command to execute to check if install/version
# alien_repository: hash (or arrayref of hashes) of information about source repo on ftp
#   |-- protocol: ftp or http
#   |-- protocol_class: holder for class type (defaults to 'Net::FTP' or 'HTTP::Tiny')
#   |-- host: ftp server for source
#   |-- folder: ftp folder containing source
#   |-- pattern: qr regex matching acceptable files, if has capture group those are version numbers
#   |-- platform: src or platform
#   |-- [platform]*: hashref of above keys for specific case (overrides defaults)
#   |
#   |-- (non-api) connection: holder for Net::FTP-like object (needs cwd, ls, and get methods)
# (non-api, set share_dir) alien_share_folder: full folder name for $self->{share_dir}
# (non-api) alien_cabinet: holder for A::B::MB::Cabinet object (holds found files)

sub new {
  my $class = shift;
  my %args = @_;

  $args{'share_dir'} = 'share' unless defined $args{'share_dir'};

  my $self = $class->SUPER::new(%args);

  my $repo_property = $self->{properties}{alien_repository};

  my $base_repo = Alien::Base::ModuleBuild::Repository->new(
    protocol       => delete $repo_property->{protocol},
    protocol_class => delete $repo_property->{protocol_class},
    host           => delete $repo_property->{host},
    folder         => delete $repo_property->{folder},
    pattern        => delete $repo_property->{pattern},
    platform       => 'src',
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

  $self->{properties}{alien_repository} = \@repos;

  $self->{properties}{alien_cabinet} = Alien::Base::ModuleBuild::Cabinet->new();

  if (! defined $self->{properties}{alien_selection_method} or $ENV{AUTOMATED_TESTING}) {
    $self->{properties}{alien_selection_method} = 'newest'
  } 

  return $self;
}

sub ACTION_code {
  my $self = shift;
  $self->alien_main_procedure;
  $self->SUPER::ACTION_code;
}

sub alien_main_procedure {
  my $self = shift;
  my $cabinet = $self->{properties}{alien_cabinet};

  foreach my $repo (@{ $self->{properties}{alien_repository} }) {
    $cabinet->add_files( $repo->probe() );
  }

  $cabinet->sort_files;

  {
    local $CWD = $self->alien_temp_folder;
    my $file = $cabinet->files->[0];
    my $filename = $file->get;

    my $ae = Archive::Extract->new( archive => $filename );
    $ae->extract;
    warn $CWD = $ae->extract_path;

    $self->alien_build;
  }
  #$repo->get_file($file);
}

sub alien_temp_folder {
  my $self = shift;

  return $self->{properties}{alien_temp_folder}
    if defined $self->{properties}{alien_temp_folder};

  my $tempdir = File::Temp->newdir();

  $self->{properties}{alien_temp_folder} = $tempdir;

  return $tempdir;
}

sub alien_share_folder {
  my $self = shift;

  return $self->{properties}{alien_share_folder}
    if defined $self->{properties}{alien_share_folder};

  my $location = do {
    my $share_dir = $self->{properties}{share_dir}{dist}[0];
    # for share_dir install get full path to share_dir
    local $CWD = $self->base_dir();
    # mkdir $share_dir unless ( -d $share_dir );
    push @CWD, $share_dir;
    "$CWD";    
  };

  return $location;
}

sub alien_check_installed_version {
  my $self = shift;
  my $name = $self->{properties}{alien_name};
  my $command = $self->{properties}{alien_version_check} || "pkg-config --modversion $name";

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

  #remove escapes (%%)
  $string =~ s/\%(?=\%)//g;

  return $string;
}

###################
#  Build Methods  #
###################

sub alien_build {
  my $self = shift;

  my $commands = 
    $self->{properties}{alien_build_commands} 
    || [ '%pconfigure --prefix=%s', 'make', 'make install' ];

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

