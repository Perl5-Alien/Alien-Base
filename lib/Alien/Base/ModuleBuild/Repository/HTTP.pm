package Alien::Base::ModuleBuild::Repository::HTTP;

use strict;
use warnings;

use Carp;

use URI;
use HTML::LinkExtor;

use Alien::Base::ModuleBuild::Utils;

use parent 'Alien::Base::ModuleBuild::Repository';

my $has_html_parser = eval { require HTML::LinkExtor; 1 };

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

  my $http = $self->connection();

  my $response = HTTP::Tiny->new->mirror( $host . $from . $file, $file );
  croak "Download failed: " . $response->{reason} unless $response->{success};

  return 1;
}

sub list_files {
  my $self = shift;

  my $host = $self->host;
  my $uri = URI->new($host);

  my $res = $self->connection->get($uri->abs($self->location));

  unless ($res->{success}) {
    carp $res->{reason};
    return ();
  }

  my @links = 
    map { $uri->abs($_) }
    $self->find_links($res->{content});

  return @links;  
}

sub find_links {
  my $self = shift;
  my ($html) = @_;

  my @links = 
    $has_html_parser 
    ? find_links_preferred($html) 
    : find_links_textbalanced($html);

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

  return @links;
}

sub find_links_textbalanced {
  my $self = shift;
  my ($html) = @_;
  return Alien::Build::ModuleBuild::Utils::find_anchor_targets($html);
}

1;

