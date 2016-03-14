package Alien::Base::ModuleBuild::Repository::FTP;

use strict;
use warnings;

our $VERSION = '0.028';
$VERSION = eval $VERSION;

use parent 'Alien::Base::ModuleBuild::Repository';

use Carp;
use Net::FTP;

sub connection {
  my $self = shift;

  return $self->{connection}
    if $self->{connection};

  # allow easy use of Net::FTP subclass
  $self->{protocol_class} ||= 'Net::FTP';

  my $server = $self->{host} 
    or croak "Must specify a host for FTP service";

  my $ftp = $self->{protocol_class}->new($server, Debug => 0)
    or croak "Cannot connect to $server: $@";

  $ftp->login() 
    or croak "Cannot login ", $ftp->message;

  if (defined $self->location) {
    $ftp->cwd($self->location) 
      or croak "Cannot change working directory ", $ftp->message;
  }

  $ftp->binary();
  $self->{connection} = $ftp;

  return $ftp;
}

sub get_file {
  my $self = shift;
  my $file = shift || croak "Must specify file to download";

  my $ftp = $self->connection();

  $ftp->get( $file ) or croak "Download failed: " . $ftp->message();

  return $file;
}

sub list_files {
  my $self = shift;
  return $self->connection->ls();
}

1;

