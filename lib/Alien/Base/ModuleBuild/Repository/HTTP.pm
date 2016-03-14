package Alien::Base::ModuleBuild::Repository::HTTP;

use strict;
use warnings;

our $VERSION = '0.028';
$VERSION = eval $VERSION;

use Carp;

use HTTP::Tiny;
use Scalar::Util qw( blessed );
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
  my $module = $self->{protocol_class};
  $module =~ s{::}{/}g;
  $module .= '.pm';
  eval { require $module; 1 }
    or croak "Could not load protocol_class '$self->{protocol_class}': $@";

  my $http = $self->{protocol_class}->new();

  $self->{connection} = $http;

  return $http;

}

sub get_file {
  my $self = shift;
  my $file = shift || croak "Must specify file to download";

  my $protocol = $self->protocol;
  my $host = $self->{host};
  my $from = $self->location;

  my $uri = $self->build_uri($protocol, $host, $from, $file);
  $file = ($uri->path_segments())[-1];
  my $res = $self->connection->mirror($uri, $file);
  my ( $is_error, $content, $headers ) = $self->check_http_response( $res );
  croak "Download failed: " . $content if $is_error;

  my $disposition = $headers->{"content-disposition"};
  if ( defined($disposition) && ($disposition =~ /filename="([^"]+)"/ || $disposition =~ /filename=([^\s]+)/)) {
    my $new_filename = $1;
    rename $file, $new_filename;
    $self->{new_filename} = $new_filename;
  }

  return $file;
}

sub list_files {
  my $self = shift;

  my $protocol = $self->protocol;
  my $host = $self->host;
  my $location = $self->location;
  my $uri = $self->build_uri($protocol, $host, $location);

  my $res = $self->connection->get($uri);

  my ( $is_error, $content, undef, $base_url ) = $self->check_http_response( $res );
  if ( $is_error ) {
    carp $content;
    return ();
  }
  
  $self->{base_url} = $base_url;

  my @links = $self->find_links($content);

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
  my ($protocol, $host, $path, $target) = @_;

  my $uri;
  if (defined $host) {
    my $base = $self->{base_url};
    unless($base)
    {
      $base = URI->new($host);
      unless (defined $base->scheme) {
        $base = URI->new(($protocol || 'http') ."://$host");
      }
      $base->path($path) if defined $path;
    }
    $uri = URI->new_abs($target, $base);
  }
  else {
    $uri = URI->new($target);
  }
  return $uri->canonical;
}

sub check_http_response {
  my ( $self, $res ) = @_;
  if ( blessed $res && $res->isa( 'HTTP::Response' ) ) {
    my %headers = map { lc $_ => $res->header($_) } $res->header_field_names;
    if ( !$res->is_success ) {
      return ( 1, $res->status_line . " " . $res->decoded_content, \%headers, $res->request->uri );
    }
    return ( 0, $res->decoded_content, \%headers, $res->request->uri );
  }
  else {
    if ( !$res->{success} ) {
      return ( 1, $res->{reason}, $res->{headers}, $res->{url} );
    }
    return ( 0, $res->{content}, $res->{headers}, $res->{url} );
  }
}

1;

