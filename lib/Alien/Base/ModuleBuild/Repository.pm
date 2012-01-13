use strict;
use warnings;

package Alien::Base::ModuleBuild::Repository;

use Carp;

sub new {
  my $class = shift;
  my ($spec) = @_;

  my $protocol = $spec->{protocol} = uc $spec->{protocol};
  croak "Unsupported protocol: $protocol" 
    unless grep {$_ eq $protocol} qw/FTP HTTP/; 

  my $obj = bless $spec, "Alien::Base::ModuleBuild::Repository::$protocol";

  return $obj;
}

sub protocol { return shift->{protocol} }

sub host {
  my $self = shift;
  $self->{host} = shift if @_;
  return $self->{host};
}

sub folder {
  my $self = shift;
  $self->{folder} = shift if @_;
  return $self->{folder};
}

sub _has_capture_groups {
  my $self = shift;
  my $re = shift;
  "" =~ /|$re/;
  return $#+;
}

package Alien::Base::ModuleBuild::Repository::HTTP;

our @ISA = 'Alien::Base::ModuleBuild::Repository';



package Alien::Base::ModuleBuild::Repository::FTP;

our @ISA = 'Alien::Base::ModuleBuild::Repository';

use Carp;
use Net::FTP;
use File::chdir;

sub connection {
  my $self = shift;

  return $self->{connection}
    if $self->{connection};

  my $server = $self->{host} 
    or croak "Must specify a host for FTP service";

  my $ftp = Net::FTP->new($server, Debug => 0)
    or croak "Cannot connect to $server: $@";

  $ftp->login() 
    or croak "Cannot login ", $ftp->message;

  if (defined $self->{folder}) {
    $ftp->cwd($self->{folder}) 
      or croak "Cannot change working directory ", $ftp->message;
  }

  $ftp->binary();
  $self->{connection} = $ftp;

  return $ftp;
}

sub probe {
  my $self = shift;
  my $platform = shift || 'src';

  croak "Unknown platform $platform"
    unless exists $self->{$platform};

  my $pattern = $self->{$platform}{pattern};

  my @files;
  if (scalar keys %{ $self->{$platform}{versions} || {} }) {

    return $self->{$platform}{versions};

  } elsif (scalar @{ $self->{$platform}{files} || [] }) {

    return $self->{$platform}{files}
      unless $pattern;

    @files = @{ $self->{$platform}{files} };

  } else {

    @files = $self->connection()->ls();
    
    $self->{$platform}{files} = \@files;

    return \@files unless $pattern;

  }

  # only get here if $pattern exists

  @files = grep { $_ =~ $pattern } @files;
  carp "Could not find any matching files" unless @files;
  $self->{$platform}{files} = \@files;

  return \@files
    unless $self->_has_capture_groups($pattern);

  my %versions = map { 
    ($_ =~ $pattern and defined $1) ? ( $1 => $_ ) : ()
  } @files;

  if (scalar keys %versions) {
    $self->{$platform}{versions} = \%versions;
    return \%versions;
  } else {
    return \@files;
  }
  
}

sub get_file {
  my $self = shift;
  my $file = shift || croak "Must specify file to download";
  my $folder = shift || die "get_file needs folder";

  my $ftp = $self->connection();

  local $CWD = "$folder";
  $ftp->get( $file ) or croak "Download failed: " . $ftp->message();

  return 1;
}

1;

