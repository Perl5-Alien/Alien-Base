use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;

eval {
  use File::Temp qw( tempfile );
  use File::Spec;
  my($fh, $filename) = tempfile();
  close $fh;
  unlink $filename;
};

if(my $error = $@)
{
  print "unable to create a tempfile, which is required properly test and use Alien::Base\n";
  print "File::Spec->tmpdir returns @{[ File::Spec->tmpdir ]}\n";
  print "diagnostic: $error\n";
  print "There is likely something wrong with your environment\n";
  exit;
}

my %make_args = (
  NAME             => 'Alien::Base',
  DISTNAME         => 'Alien-Base',
  LICENSE          => 'perl',
  MIN_PERL_VERSION => '5.008001',
  VERSION_FROM     => 'lib/Alien/Base.pm',
  AUTHOR           => [
    'Graham Ollis <plicease@cpan.org>',
    'Joel A. Berger <joel.a.berger@gmail.com>',
  ],

  CONFIGURE_REQUIRES => {
    'ExtUtils::MakeMaker' => 0,
  },
  PREREQ_PM => {
    'Capture::Tiny'             => 0.17,
    'File::ShareDir'            => 0,
    'Text::ParseWords'          => '3.26',
    'FFI::CheckLib'             => 0.11,
    'JSON::PP'                  => 0,
    'Alien::Base::ModuleBuild'  => '0.040',
  },
  BUILD_REQUIRES => {},
  TEST_REQUIRES => {
    'Test2::V0'                 => '0.000071',
    'Test2::Suite'              => '0.000071',
    'Test2'                     => '1.302015',
    'File::chdir'               => 0.1005,
  },

  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url  => "http://github.com/Perl5-Alien/Alien-Base.git",
        web  => "http://github.com/Perl5-Alien/Alien-Base",
      },
      bugtracker => {
        web => "http://github.com/Perl5-Alien/Alien-Base/issues",
      },
      homepage => "https://metacpan.org/pod/Alien::Base",
      x_MailingList => "https://groups.google.com/forum/#!forum/perl5-alien",
      x_IRC => "irc://irc.perl.org/#native",
    },
    no_index => {
      directory => [
        "corpus",
        "maint",
      ],
    },
    dynamic_config => 1,
  },

  clean => {
    FILES => '_Inline Alien-Base-*',
  },
);

if($ENV{ALIEN_BASE_NO_ABMB})
{
  delete $make_args{'PREREQ_PM'}->{'Alien::Base::ModuleBuild'};
}

unless(`pkg-config --version` && $? == 0) {
  $make_args{'PREREQ_PM'}->{'PkgConfig'} = '0.07520';
}

# For now we prefer PkgConfig.pm over pkg-config on
# Solaris 64 bit Perls.  We may need to do this on
# other platforms, in which case this logic should
# be abstracted so that it can be shared here and
# in lib/Alien/Base.pm#pkg_config_command
if($^O eq 'solaris' && $Config{ptrsize} == 8) {
  $make_args{'PREREQ_PM'}->{'PkgConfig'} = '0.08826';
}


my %fallback = (
  %{ $make_args{TEST_REQUIRES} },
  %{ $make_args{BUILD_REQUIRES} },
  %{ $make_args{PREREQ_PM} },
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  $make_args{PREREQ_PM} = \%fallback;
  delete $make_args{TEST_REQUIRES};
  delete $make_args{BUILD_REQUIRES};
}

delete $make_args{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%make_args);
