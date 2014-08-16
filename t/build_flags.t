use Test::More;

use Alien::Base ();

my %unix_flags = (
  q{ -L/a/b/c -lz -L/a/b/c } => [ "-L/a/b/c", "-lz", "-L/a/b/c" ],
);

my %win_flags = (
  q{ -L/a/b/c -lz -L/a/b/c } => [ "-L/a/b/c", "-lz", "-L/a/b/c" ],
  q{ -LC:/a/b/c -lz -L"C:/a/b c/d" } => [ "-LC:/a/b/c", "-lz", "-LC:/a/b c/d" ],
  q{ -LC:\a\b\c -lz } => [ q{-LC:\a\b\c}, "-lz" ],
);

subtest 'unix' => sub {
  while ( my ($flag, $split) = each %unix_flags ) {
    is_deeply( [ Alien::Base->split_flags_unix( $flag ) ], $split );
  }
};

subtest 'windows' => sub {
  while ( my ($flag, $split) = each %win_flags ) {
    is_deeply( [ Alien::Base->split_flags_windows( $flag ) ], $split );
  }
};

done_testing;
