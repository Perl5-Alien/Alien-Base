use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild::Repository::HTTP');

my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new;

{
  my $uri = $repo->build_uri('host.com', 'path');
  is $uri, 'http://host.com/path', 'simplest case';
}

{
  my $uri = $repo->build_uri('host.com', 'my path');
  is $uri, 'http://host.com/my%20path', 'path with spaces';
}

{
  my $uri = $repo->build_uri('host.com', 'deeper', 'my path');
  is $uri, 'http://host.com/deeper/my%20path', 'extended path with spaces';
}

{
  my $uri = $repo->build_uri('host.com/', '/path');
  is $uri, 'http://host.com/path', 'remove repeated /';
}

{
  my $uri = $repo->build_uri('host.com/', '/path/', 'file.ext');
  is $uri, 'http://host.com/path/file.ext', 'file with path';
}

done_testing;

