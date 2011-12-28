package Alien::Base::ModuleBuild;

use strict;
use warnings;

use parent 'Module::Build';

use Capture::Tiny 'capture_stderr';
use Sort::Versions;
use Net::FTP;
use File::chdir;
use Carp;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= 0;

## Extra parameters in $self (all (toplevel) should start with 'alien_')
# alien_name -- name of library 
# alien_temp_foler -- folder name or File::Temp object for download/build
# alien_version_check -- command to execute to check if install/version
# alien_source_ftp -- hash of information about source repo on ftp
#   server -- ftp server for source
#   folder -- ftp folder containing source
#   ftp  -- holder for Net::FTP object (non-api)
#   data -- holder for data (non-api)
#     files -- holder for found files (on ftp server)
#     versions -- holder for version=>file

sub alien_temp_folder {
  my $self = shift;

  return $self->{alien_temp_folder}
    if defined $self->{alien_temp_folder};

  my $tempdir = File::Temp->newdir();

  $self->{alien_temp_folder} = $tempdir;

  return $tempdir;
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

sub alien_ftp_connection {
  my $self = shift;
  my $key = shift || croak "Must specify what FTP information to use";

  return $self->{$key}{ftp}
    if defined $self->{$key}{ftp};

  my $server = $self->{$key}{server} 
    or croak "Must specify a server when using ftp service";

  my $ftp = Net::FTP->new($server, Debug => 0)
    or croak "Cannot connect to $server: $@";

  $ftp->login() 
    or croak "Cannot login ", $ftp->message;

  if (defined $self->{$key}{folder}) {
    $ftp->cwd($self->{$key}{folder}) 
      or croak "Cannot change working directory ", $ftp->message;
  }

  $ftp->binary();
  $self->{$key}{ftp} = $ftp;

  return $ftp;
}

sub alien_probe_source_ftp {
  my $self = shift;

  my $pattern = $self->{alien_source_ftp}{pattern};

  my @files;
  if (scalar keys %{ $self->{alien_source_ftp}{data}{versions} || {} }) {

    return $self->{alien_source_ftp}{data}{versions};

  } elsif (scalar @{ $self->{alien_source_ftp}{data}{files} || [] }) {

    return $self->{alien_source_ftp}{data}{files}
      unless $pattern;

    @files = @{ $self->{alien_source_ftp}{data}{files} };

  } else {

    croak "No alien_source_ftp information given"
      unless scalar keys %{ $self->{alien_source_ftp} || {} };

    @files = $self->alien_ftp_connection('alien_source_ftp')->ls();
    
    $self->{alien_source_ftp}{data}{files} = \@files;

    return \@files unless $pattern;

  }

  # only get here if $pattern exists

  @files = grep { $_ =~ $pattern } @files;
  carp "Could not find any matching files" unless @files;
  $self->{alien_source_ftp}{data}{files} = \@files;

  return \@files
    unless _alien_has_capture_groups($pattern);

  my %versions = 
    map { 
      if ($_ =~ $pattern and defined $1) { 
        ( $1 => $_ )
      } else {
        ()
      }
    } 
    @files;

  if (scalar keys %versions) {
    $self->{alien_source_ftp}{data}{versions} = \%versions;
    return \%versions;
  } else {
    return \@files;
  }
  
}

sub alien_get_file_ftp {
  my $self = shift;
  my $key = shift || croak "Must specify what FTP information to use";
  my $file = shift || croak "Must specify file to download";

  my $ftp = $self->alien_ftp_connection($key);
  my $tempdir = $self->alien_temp_folder;

  local $CWD = "$tempdir";
  $ftp->get( $file ) or croak "Download failed: " . $ftp->message();

  return 1;
}

# helper functions

sub _alien_has_capture_groups {
  my $re = shift;
  "" =~ /|$re/;
  return $#+;
}

1;

