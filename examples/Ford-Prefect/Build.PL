use strict;
use warnings;

use Module::Build;
use Alien::DontPanic;

my $dontpanic = Alien::DontPanic->new;

my $pc = $dontpanic->pkgconfig('dontpanic');

my $cflags = $pc->keyword('Cflags');
my $libs   = $pc->keyword('Libs');

my $builder = Module::Build->new(
    module_name       => 'Ford::Prefect',
    dist_abstract     => 'Part of the test framework for Alien::Base',
    dist_author       => 'Joel Berger <joel.a.berger@gmail.com>',
    license           => 'perl',
    requires          => {
      'perl' => '5.008',
    },
    configure_requires => {
      'Module::Build' => 0.38,
    },
    build_requires    => {
      'ExtUtils::CBuilder' => 0,
    },
    extra_compiler_flags => $cflags,
    extra_linker_flags   => $libs, 
);

$builder->create_build_script;

# for do-loading
no warnings 'void';
$builder;

