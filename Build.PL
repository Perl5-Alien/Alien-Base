use strict;
use warnings;
use Config;
use Module::Build;

my %build_args = (
  module_name => 'Alien::Base',
  dist_name => 'Alien-Base',
  dist_abstract => 'A base class for Alien:: modules',
  dist_author => [
    'Graham Ollis <plicease@cpan.org>',
    'Joel A. Berger <joel.a.berger@gmail.com>',
  ],
  license  => 'perl',
  configure_requires => {
    'Module::Build' => 0.36,
  },
  requires => {
    'perl'                      => '5.8.1',
    'Capture::Tiny'             => 0.17,
    'File::ShareDir'            => 0,
    'Text::ParseWords'          => '3.26',
    'FFI::CheckLib'             => 0.11,
    'JSON::PP'                  => 0,
    'Alien::Base::ModuleBuild' => '0.038',
  },
  test_requires => {
    'Test2::Suite'     => '0.000060',
    'Test::More'       => 0.94,
    'File::chdir'      => 0.1005,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/Perl5-Alien/Alien-Base",
      bugtracker => "http://github.com/Perl5-Alien/Alien-Base/issues",
      x_MailingList => 'https://groups.google.com/forum/#!forum/perl5-alien',
      x_IRC => "irc://irc.perl.org/#native",
    },
    no_index => {
      file      => [ 'README.pod' ],
      directory => [ 't' ],
    },
  },
);

if($ENV{ALIEN_BASE_NO_ABMB})
{
  delete $build_args{requires}->{'Alien::Base::ModuleBuild'};
}

unless (`pkg-config --version` && $? == 0) {
  $build_args{'requires'}->{'PkgConfig'} = '0.07520';
}

# For now we prefer PkgConfig.pm over pkg-config on
# Solaris 64 bit Perls.  We may need to do this on
# other platforms, in which case this logic should
# be abstracted so that it can be shared here and
# in lib/Alien/Base.pm#pkg_config_command
if($^O eq 'solaris' && $Config{ptrsize} == 8) {
  $build_args{'requires'}->{'PkgConfig'} = '0.08826';
}

my $builder = Module::Build->new(%build_args);
$builder->add_to_cleanup( '_Inline', 'Alien-Base-*' );
$builder->create_build_script;
