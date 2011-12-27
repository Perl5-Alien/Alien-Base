package Alien::Base;

use parent 'Module::Build';

use Capture::Tiny 'capture_stderr';

our $VERSION = 0.01;
$VERSION = eval $VERSION;

our $Verbose ||= 0;

## Extra parameters in $self (all should start with 'alien_')
# alien_name -- name of library 
# alien_version_check -- command to execute to check if install/version

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

1;

