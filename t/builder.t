use strict;
use warnings;

use Test::More;

use Alien::Base::ModuleBuild;
use File::chdir;
use File::Temp ();
use File::Path qw( rmtree mkpath );
use Capture::Tiny qw( capture );
use FindBin ();

my $dir = File::Temp->newdir;
local $CWD = "$dir";

my %basic = (
  module_name  => 'My::Test',
  dist_version => '0.01',
  dist_author  => 'Joel Berger',
);

sub output_to_note (&) {
  my $sub = shift;
  my($out, $err) = capture { $sub->() };
  note "[out]\n$out" if $out;
  note "[err]\n$err" if $err;
}

our $mb_class = 'Alien::Base::ModuleBuild';

sub builder {
  my @args = @_;
  my $builder;
  output_to_note { $builder = $mb_class->new( %basic, @args ) };
  $builder;
}

###########################
#  Temporary Directories  #
###########################

subtest 'default temp and share' => sub {
  rmtree [qw/_alien _share/], 0, 1;

  my $builder = builder;

  # test the builder function
  isa_ok($builder, 'Alien::Base::ModuleBuild');
  isa_ok($builder, 'Module::Build');

  $builder->alien_init_temp_dir;
  ok( -d '_alien', "Creates _alien dir");
  ok( -d '_share', "Creates _share dir");

  output_to_note { $builder->depends_on('clean') };
  ok( ! -d '_alien', "Removes _alien dir");
  ok( ! -d '_share', "Removes _share dir");

  rmtree [qw/_alien _share/], 0, 1;
};

subtest 'override temp and share' => sub {
  rmtree [qw/_test_temp _test_share/], 0, 1;

  my $builder = builder(
    alien_temp_dir => '_test_temp',
    alien_share_dir => '_test_share',
  );

  $builder->alien_init_temp_dir;
  ok( -d '_test_temp', "Creates _test_temp dir");
  ok( -d '_test_share', "Creates _test_temp dir");

  output_to_note { $builder->depends_on('clean') };
  ok( ! -d '_test_temp', "Removes _test_temp dir");
  ok( ! -d '_test_share', "Removes _test_share dir");

  rmtree [qw/_test_temp _test_share/], 0, 1;
};

subtest 'destdir' => sub {
  plan skip_all => 'TODO on MSWin32' if $^O eq 'MSWin32';

  $ENV{ALIEN_BLIB} = 0;

  open my $fh, '>', 'build.pl';
  print $fh <<'EOF';
use strict;
use warnings;
use File::Copy qw( copy );

my $cmd = shift;
@ARGV = map { s/DESTDIR/$ENV{DESTDIR}/g; $_ } @ARGV;
print "% $cmd @ARGV\n";
if($cmd eq 'mkdir')    { mkdir shift } 
elsif($cmd eq 'touch') { open my $fh, '>', shift; close $fh; }
elsif($cmd eq 'copy')  { copy shift, shift }
EOF
  close $fh;

  my $destdir = File::Temp->newdir;
  
  mkdir 'src';
  open $fh, '>', 'src/foo.tar.gz';
  binmode $fh;
  print $fh unpack("u", 
              q{M'XL(`%)-#E0``TO+S]=GH#$P,#`P-S55`-*&YJ8&R#0<*!@:F1@8FYB8F1J:} .
              q{M*A@`.>:&#`JFM'88")06ER06`9V2GY.369R.6QTA>:@_X/00`6G`^-=+K<@L} .
              q{L+BFFF1W`\#`S,2$E_HW-S<T9%`QHYB(D,,+C?Q2,@E$P<@$`7EO"E``(````}
            );
  close $fh;
  
  my $builder = builder(
    alien_name => 'foobarbazfakething',
    alien_build_commands => [
      "$^X $CWD/build.pl mkdir bin",
      "$^X $CWD/build.pl touch bin/foo",
    ],
    alien_install_commands => [
      "$^X $CWD/build.pl mkdir DESTDIR/%s/bin",
      "$^X $CWD/build.pl copy  bin/foo DESTDIR/%s/bin/foo",
    ],
    alien_repository => {
      protocol => 'local',
      location => 'src',
      c_compiler_required => 0,
    },
  );

  my $share = $builder->alien_library_destination;
  
  output_to_note { $builder->depends_on('build') };

  $builder->destdir($destdir);  
  is $builder->destdir, $destdir, "destdir accessor";
  
  output_to_note { $builder->depends_on('install') };

  my $foo_script = File::Spec->catfile($destdir, $share, 'bin', 'foo');
  ok -e $foo_script, "script installed in destdir $foo_script";
    
  unlink 'build.pl';
  rmtree [qw/ _alien  _share  blib  src /], 0, 0;
};

subtest 'alien_bin_requires' => sub {

  my $bin = File::Spec->catdir($FindBin::Bin, 'builder', 'bin');
  note "bin = $bin";

  eval q{
    package Alien::Libfoo;

    our $VERSION = '1.00';
    
    $INC{'Alien/Libfoo.pm'} = __FILE__;

    package Alien::ToolFoo;

    our $VERSION = '0.37';
    
    $INC{'Alien/ToolFoo.pm'} = __FILE__;
    
    sub bin_dir {
      ($bin)
    }
  };

  my $builder = builder(
    alien_name => 'foobarbazfakething',
    build_requires => {
      'Alien::Libfoo' => '1.00',
    },
    alien_bin_requires => {
      'Alien::ToolFoo' => '0.37',
    },
    alien_build_commands => [
      '/bin/true',
    ],
  );

  is $builder->build_requires->{"Alien::MSYS"},     undef, 'no Alien::MSYS';
  is $builder->build_requires->{"Alien::Libfoo"},  '1.00', 'normal build requires';
  is $builder->build_requires->{"Alien::ToolFoo"}, '0.37', 'alien_bin_requires implies a build requires';

  my %status;
  output_to_note { 
    local $CWD;
    my $dir = File::Spec->catdir(qw( _alien buildroot ));
    mkpath($dir, { verbose => 0 });
    $CWD = $dir;
    %status = $builder->_env_do_system('privateapp');
  };
  ok $status{success}, 'found privateapp in path';
  if($^O eq 'MSWin32') {
    ok -e File::Spec->catfile(qw( _alien env.cmd )), 'cmd shell helper';
    ok -e File::Spec->catfile(qw( _alien env.bat )), 'bat shell helper';
    ok -e File::Spec->catfile(qw( _alien env.ps1 )), 'power shell helper';
  } else {
    ok -e File::Spec->catfile(qw( _alien env.sh )), 'bourne shell helper';
    ok -e File::Spec->catfile(qw( _alien env.csh )), 'c shell helper';
  }

  rmtree [qw/ _alien /], 0, 0;
};

subtest 'alien_check_built_version' => sub {

  open my $fh, '>', 'build.pl';
  print $fh <<'EOF';
exit 0;
EOF
  close $fh;

  mkdir 'src';
  open $fh, '>', 'src/foo.tar.gz';
  binmode $fh;
  print $fh unpack("u", 
    q{M'XL(`)"=)%0``^W1P0K",`P&X)Y]BCQ!36K2GGP8#YL,AH6UBH]OA#%DH)ZJ} .
    q{MB/DNH;30O_W[G+>N,41,(J"3DN#C7``%)A4C$:`N)#F0UL'NSJ4>)HV2QW$H} .
    q{MQ^?GWNW/[UCFC^BU_TLWE2&??+W6)G?H?T3F%_V'=?\<DSC`)FE6_KS_N7O8} .
    q{50_`[SYMOYS'&&/,9-ZR`#EH`"@``}
  );
  close $fh;

  eval q{
    package My::ModuleBuild1;
    
    use base qw( Alien::Base::ModuleBuild );
    
    sub alien_check_built_version {
      open my $fh, '<', 'version.txt';
      my $txt = <$fh>;
      close $fh;
      $txt =~ /version = ([0-9.]+)/ ? $1 : ();
    }
  };
  die $@ if $@;

  local $mb_class = 'My::ModuleBuild1';
  
  my $builder = builder(
    alien_name => 'foobarbazfakething',
    alien_build_commands => [
      "$^X $CWD/build.pl",
    ],
    alien_install_commands => [
      "$^X $CWD/build.pl",
    ],
    alien_repository => {
      protocol => 'local',
      location => 'src',
      c_compiler_required => 0,
    },
  );
  
  output_to_note { $builder->depends_on('build') };

  is $builder->config_data( 'version' ), '2.3.4', 'version is set correctly';

  unlink 'build.pl';
  rmtree [qw/ _alien  _share  blib  src /], 0, 0;
};

done_testing;
