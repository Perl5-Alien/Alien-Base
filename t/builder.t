use strict;
use warnings;

use Test::More;

use Alien::Base::ModuleBuild;
use File::chdir;
use File::Temp ();
use File::Path qw( rmtree );

my $dir = File::Temp->newdir;
local $CWD = "$dir";

my %basic = (
  module_name  => 'My::Test',
  dist_version => '0.01',
  dist_author  => 'Joel Berger',
);

sub builder { return Alien::Base::ModuleBuild->new( %basic, @_ ) }

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

  $builder->depends_on('clean');
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

  $builder->depends_on('clean');
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
    },
  );

  my $share = $builder->alien_library_destination;
  
  $builder->depends_on('build');

  $builder->destdir($destdir);  
  is $builder->destdir, $destdir, "destdir accessor";
  
  $builder->depends_on('install');

  my $foo_script = File::Spec->catfile($destdir, $share, 'bin', 'foo');
  ok -e $foo_script, "script installed in destdir $foo_script";
    
  unlink 'build.pl';
  rmtree [qw/ _alien  _share  blib  src /], 0, 0;
};

done_testing;

