use strict;
use warnings;

use Test::More;
use Cwd qw( abs_path );
use File::chdir;
use FindBin;
use File::Spec;
use File::Temp;
use URI::file;

my $FILE_HOST = File::Spec->catdir( abs_path( $FindBin::Bin ), 'test_http' );
my $INDEX_PATH = File::Spec->catfile( $FILE_HOST, 'index.html' );
{
  package Test::Alien::Base::HTTP;

  sub new {
    return bless {}, __PACKAGE__;
  }

  sub get {
    local $/ = undef;
    open my $fh, '<', $INDEX_PATH or die "Could not open $INDEX_PATH: $!";
    return {
      success => 1,
      content => <$fh>,
    };
  }

  sub mirror {
    return {
      success => 1,
    };
  }
}
$INC{'Test/Alien/Base/HTTP.pm'} = __FILE__;

use_ok('Alien::Base::ModuleBuild::Repository::HTTP');

my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new;

# replicated in utils.t
my $html = q#Some <a href=link>link text</a> stuff. And a little <A HREF="link2">different link text</a>. AN ALL CAPS TAG <A HREF="link3">ALL CAPS</A> <A HREF=link4>ALL CAPS NO QUOTES</A>. <!--  <a href="dont_follow.html">you can't see me!</a> -->#;
my $correct = [qw/link link2 link3 link4/];

SKIP: {
  no warnings 'once';
  skip "HTML::LinkExtor not detected", 2 
    unless $Alien::Base::ModuleBuild::Repository::HTTP::Has_HTML_Parser; 

  my @targets = $repo->find_links_preferred($html);
  is_deeply( \@targets, $correct, "parse HTML for anchor targets (HTML::LinkExtor)");

  my @disp_targets = $repo->find_links($html);
  is_deeply( \@disp_targets, $correct, "parse HTML for anchor targets (HTML::LinkExtor, dispatched)");
}

{
  my @targets = $repo->find_links_textbalanced($html);
  is_deeply( \@targets, $correct, "parse HTML for anchor targets (Text::Balanced)");

  # force Text::Balanced in dispatcher
  $Alien::Base::ModuleBuild::Repository::HTTP::Has_HTML_Parser = 0;
  my @disp_targets = $repo->find_links($html);
  is_deeply( \@disp_targets, $correct, "parse HTML for anchor targets (Text::Balanced, dispatched)");
}

subtest 'connection() and protocol_class' => sub {
  subtest 'HTTP::Tiny' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'HTTP::Tiny',
    );
    isa_ok $repo->connection, 'HTTP::Tiny', 'default HTTP class';
  };

  subtest 'LWP::UserAgent' => sub {
    plan skip_all => 'No LWP::UserAgent detected'
      unless eval { require LWP::UserAgent; 1 };
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'LWP::UserAgent',
    );
    isa_ok $repo->connection, 'LWP::UserAgent';
  };

  subtest 'default' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new;
    isa_ok $repo->connection, 'HTTP::Tiny', 'default HTTP class';
  };

  subtest 'invalid class' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'THISCOULDNEVERBEAPROTOCOLCLASSWHATAREYOUTHINKING',
    );
    eval { $repo->connection };
    like $@, qr{Could not load protocol_class};
  };
};

subtest 'list_files()' => sub {
  subtest 'mock client' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'Test::Alien::Base::HTTP',
      host => 'http://example.com',
      location => '/index.html',
    );
    is_deeply [ $repo->list_files ], [ 'relativepackage.txt' ];
  };
  subtest 'LWP::UserAgent' => sub {
    plan skip_all => 'No LWP::UserAgent' unless eval { require LWP::UserAgent; 1 };
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'LWP::UserAgent',
      host => URI::file->new($INDEX_PATH)->as_string,
      # location doesn't work for file:// URLs
    );
    is_deeply [ $repo->list_files ], [ 'relativepackage.txt' ];
  };
};

subtest 'get_file()' => sub {
  subtest 'mock client' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'Test::Alien::Base::HTTP',
    );
    my $file = $repo->get_file( 'http://example.com/test.tar.gz' );
    is $file, 'test.tar.gz';
  };
  subtest 'LWP::UserAgent' => sub {
    plan skip_all => 'No LWP::UserAgent' unless eval { require LWP::UserAgent; 1 };
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'LWP::UserAgent',
    );
    # Change to a tempdir so our file gets automatically cleaned up
    my $tmp = File::Temp->newdir;
    local $CWD = $tmp->dirname;

    my $file = $repo->get_file( URI::file->new($INDEX_PATH)->as_string );
    is $file, 'index.html';
  };
};

subtest 'get()' => sub {
  subtest 'mock client' => sub {
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'Test::Alien::Base::HTTP',
    );
    my $file = Alien::Base::ModuleBuild::File->new(
      repository => $repo,
      filename => 'http://example.com/test.tar.gz',
    );
    my $filename = $file->get();
    is $filename, 'test.tar.gz';
  };
  subtest 'LWP::UserAgent' => sub {
    plan skip_all => 'No LWP::UserAgent' unless eval { require LWP::UserAgent; 1 };
    my $repo = Alien::Base::ModuleBuild::Repository::HTTP->new(
      protocol_class => 'LWP::UserAgent',
    );
    # Change to a tempdir so our file gets automatically cleaned up
    my $tmp = File::Temp->newdir;
    local $CWD = $tmp->dirname;

    my $file = Alien::Base::ModuleBuild::File->new(
      repository => $repo,
      filename => URI::file->new($INDEX_PATH)->as_string,
    );
    my $filename = $file->get();
    is $filename, 'index.html';
  };
};

done_testing;

