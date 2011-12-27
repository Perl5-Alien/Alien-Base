package Alien::Base;

use parent 'Module::Build';

use Capture::Tiny 'capture_stderr';
use Sort::Versions;
use Net::FTP;
use Carp;

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= 0;

## Extra parameters in $self (all should start with 'alien_')
# alien_name -- name of library 
# alien_version_check -- command to execute to check if install/version
# alien_source_ftp -- hash of information about source repo on ftp

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

sub alien_probe_source_ftp {
  my $self = shift;

  my @files;
  if (defined $self->{alien_source_ftp}{data}{files}) {

    @files = @{ $self->{alien_source_ftp}{data}{files} };

  } else {

    croak "No alien_source_ftp information given"
      unless $self->{alien_source_ftp};

    my $server = $self->{alien_source_ftp}{server} 
      or croak "Must specify a server when using ftp service";

    my $ftp = Net::FTP->new($server, Debug => 0)
      or croak "Cannot connect to $server: $@";

    $ftp->login() 
      or croak "Cannot login ", $ftp->message;

    if (defined $self->{alien_source_ftp}{folder}) {
      $ftp->cwd($self->{alien_source_ftp}{folder}) 
        or croak "Cannot change working directory ", $ftp->message;
    }

    @files = $ftp->ls();
    
    $self->{alien_source_ftp}{data}{files} = \@files;
    $self->{alien_source_ftp}{data}{ftp} = $ftp;

  }

  my $pattern = $self->{alien_source_ftp}{pattern};
  unless ($pattern) {
    return \@files;
  }

  @files = grep { $_ =~ $pattern } @files;
  carp "Could not find any matching files" unless @files;
  $self->{alien_source_ftp}{data}{files} = \@files;

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

1;

