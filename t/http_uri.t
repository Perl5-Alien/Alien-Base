use strict;
use warnings;

use Test::More;

use_ok('Alien::Base::ModuleBuild::Repository::HTTP');

my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new;

{
  my $uri = $repo->build_uri('http','host.com', 'path');
  is $uri, 'http://host.com/path', 'simplest case';
}

{
  my $uri = $repo->build_uri('https','host.com', 'path');
  is $uri, 'https://host.com/path', 'simplest case with the HTTPS protocol';
}

{
  my $uri = $repo->build_uri('http','host.com', 'my path');
  is $uri, 'http://host.com/my%20path', 'path with spaces';
}

{
  my $uri = $repo->build_uri('http','host.com', 'deeper/', 'my path');
  is $uri, 'http://host.com/deeper/my%20path', 'extended path with spaces';
}

{
  my $uri = $repo->build_uri('http','host.com/', '/path');
  is $uri, 'http://host.com/path', 'remove repeated /';
}

{
  my $uri = $repo->build_uri('http','host.com/', '/path/', 'file.ext');
  is $uri, 'http://host.com/path/file.ext', 'file with path';
}

{
  my $uri = $repo->build_uri('http','host.com/', '/path/', 'http://host.com/other/file.ext');
  is $uri, 'http://host.com/other/file.ext', 'absolute URI found in link';
}

{
  my $uri = $repo->build_uri('http','host.com/', '/path/', 'http://example.org/other/file.ext');
  is $uri, 'http://example.org/other/file.ext', 'absolute URI on different host';
}

{
  my $uri = $repo->build_uri('https', 'github.com', '/libssh2/libssh2/releases/',
                             '/libssh2/libssh2/releases/download/libssh2-1.6.0/libssh2-1.6.0.tar.gz');
  is $uri, 'https://github.com/libssh2/libssh2/releases/download/libssh2-1.6.0/libssh2-1.6.0.tar.gz';
}

done_testing;

