use strict;
use warnings;
use Test::More tests => 7;

my $content_disposition;

eval q{
  package HTTP::Tiny;

  sub new {
    bless {}, 'HTTP::Tiny';
  }
  
  sub mirror {
    my $response = { success => 1 };
    $response->{headers}->{'content-disposition'} = $content_disposition
      if defined $content_disposition;
    $response;
  }
  
  $INC{'HTTP/Tiny.pm'} = __FILE__;
};

use_ok 'Alien::Base::ModuleBuild::Repository::HTTP';
use_ok 'Alien::Base::ModuleBuild::File';

my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
  host => 'foo.bar.com',
);

is Alien::Base::ModuleBuild::File->new( repository => $repo, filename => 'bogus' )->get, 'bogus', 'no content disposition';

$content_disposition = 'attachment; filename=foo.txt';

is Alien::Base::ModuleBuild::File->new( repository => $repo, filename => 'bogus' )->get, 'foo.txt', 'filename = foo.txt (bare)';

$content_disposition = 'attachment; filename="foo.txt"';

is Alien::Base::ModuleBuild::File->new( repository => $repo, filename => 'bogus' )->get, 'foo.txt', 'filename = foo.txt (double quotes)';

$content_disposition = 'attachment; filename="foo with space.txt" and some other stuff';

is Alien::Base::ModuleBuild::File->new( repository => $repo, filename => 'bogus' )->get, 'foo with space.txt', 'filename = foo with space.txt (double quotes with space)';

$content_disposition = 'attachment; filename=foo.txt and some other stuff';

is Alien::Base::ModuleBuild::File->new( repository => $repo, filename => 'bogus' )->get, 'foo.txt', 'filename = foo.txt (space terminated)';
