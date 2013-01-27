package Alien::Base::ModuleBuild::Repository::HTTP;

use strict;
use warnings;

our $VERSION = '0.002';
$VERSION = eval $VERSION;

use Carp;

use HTTP::Tiny;
use URI;

use Alien::Base::ModuleBuild::Utils;

use parent 'Alien::Base::ModuleBuild::Repository';

our $Has_HTML_Parser = eval { require HTML::LinkExtor; 1 };

sub connection {

  my $self = shift;

  return $self->{connection}
    if $self->{connection};

  # allow easy use of HTTP::Tiny subclass
  $self->{protocol_class} ||= 'HTTP::Tiny';

  my $http = $self->{protocol_class}->new();

  $self->{connection} = $http;

  return $http;

}

sub get_file {
  my $self = shift;
  my $file = shift || croak "Must specify file to download";

  my $host = $self->{host};
  my $from = $self->location;

  my $uri = $self->build_uri($host, $from, $file);
  my $response = $self->connection->mirror($uri, $file);
  croak "Download failed: " . $response->{reason} unless $response->{success};

  return 1;
}

sub list_files {
  my $self = shift;

  my $host = $self->host;
  my $location = $self->location;
  my $uri = $self->build_uri($host, $location);

  my $res = $self->connection->get($uri);

  unless ($res->{success}) {
    carp $res->{reason};
    return ();
  }

  my @links = $self->find_links($res->{content});

  return @links;  
}

sub find_links {
  my $self = shift;
  my ($html) = @_;

  my @links;
  if ($Has_HTML_Parser) {
    push @links, $self->find_links_preferred($html) 
  } else {
    push @links, $self->find_links_textbalanced($html)
  }

  return @links;
}

sub find_links_preferred {
  my $self = shift;
  my ($html) = @_;

  my @links;

  my $extor = HTML::LinkExtor->new(
    sub { 
      my ($tag, %attrs) = @_;
      return unless $tag eq 'a';
      return unless defined $attrs{href};
      push @links, $attrs{href};
    },
  );

  $extor->parse($html);

  return @links;
}

sub find_links_textbalanced {
  my $self = shift;
  my ($html) = @_;
  return Alien::Base::ModuleBuild::Utils::find_anchor_targets($html);
}

sub build_uri {
  my $self = shift;
  my ($host, $path, $file) = @_;

  unless ( $host =~ m'^http://' ) {
    $host = "http://$host";
  }
  my $uri = URI->new( $host );
  return $uri unless defined $path;

  $path =~ s'/$'';
  $uri->path( $path );
  return $uri->canonical unless defined $file;

  my @segments = $uri->path_segments;
  shift @segments;
  $uri->path_segments( @segments, $file );

  return $uri->canonical;
}

1;

