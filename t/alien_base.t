use Test2::Bundle::Extended;
use lib 'corpus/lib';
use lib 't/alien_base/mb_share/lib';
use lib 't/alien_base/mb_sys/lib';
use Env qw( @PKG_CONFIG_PATH );
use File::Glob qw( bsd_glob );
use File::chdir;
use File::Spec;

unshift @PKG_CONFIG_PATH, File::Spec->rel2abs(File::Spec->catdir( qw( t alien_base pkgconfig )));

subtest 'AB::MB sys install' => sub {

  require Alien::Foo1;

  my $cflags  = Alien::Foo1->cflags;
  my $libs    = Alien::Foo1->libs;
  my $version = Alien::Foo1->version;

  $libs =~ s{^\s+}{};

  is $cflags, '-DFOO=stuff', "cflags: $cflags";
  is $libs,   '-lfoo1', "libs: $libs";
  is $version, '3.99999', "version: $version";
};

subtest 'AB::MB share install' => sub {

  require Alien::Foo2;

  my $cflags  = Alien::Foo2->cflags;
  my $libs    = Alien::Foo2->libs;
  my $version = Alien::Foo2->version;
    
  ok $cflags,  "cflags: $cflags";
  ok $libs,    "libs:   $libs";
  is $version, '3.2.1', "version: $version";

  if($cflags =~ /-I(.*)$/)
  {
    ok -f "$1/foo2.h", "include path: $1";
  }
  else
  {
    fail "include path: ?";
  }
  
  if($libs =~ /-L([^ ]*)/)
  {
    ok -f "$1/libfoo2.a", "lib path: $1";
  }
  else
  {
    fail "lib path: ?";
  }

};

subtest 'Alien::Build system' => sub {

  require Alien::libfoo1;
  
  is( -f File::Spec->catfile(Alien::libfoo1->dist_dir,'_alien/for_libfoo1'), T(), 'dist_dir');
  is( Alien::libfoo1->cflags, '-DFOO=1', 'cflags' );
  is( Alien::libfoo1->cflags_static, '-DFOO=1 -DFOO_STATIC=1', 'cflags_static');
  is( Alien::libfoo1->libs, '-lfoo', 'libs' );
  is( Alien::libfoo1->libs_static, '-lfoo -lbar -lbaz', 'libs_static' );
  is( Alien::libfoo1->version, '1.2.3', 'version');
  
  subtest 'install type' => sub {
    is( Alien::libfoo1->install_type, 'system' );
    is( Alien::libfoo1->install_type('system'), T() );
    is( Alien::libfoo1->install_type('share'), F() );
  };
  
  is( Alien::libfoo1->config('name'), 'foo', 'config.name' );
  is( Alien::libfoo1->config('finished_installing'), T(), 'config.finished_installing' );

  is( [Alien::libfoo1->dynamic_libs], ['/usr/lib/libfoo.so','/usr/lib/libfoo.so.1'], 'dynamic_libs' );
  
  is( [Alien::libfoo1->bin_dir], [], 'bin_dir' );
  
  is( Alien::libfoo1->runtime_prop->{arbitrary}, 'one', 'runtime_prop' );
};

subtest 'Alien::Build share' => sub {

  require Alien::libfoo2;
  
  is( -f File::Spec->catfile(Alien::libfoo2->dist_dir,'_alien/for_libfoo2'), T(), 'dist_dir');
  
  subtest 'cflags' => sub {
    is(
      [split /\s+/, Alien::libfoo2->cflags],
      array {
        item match qr/^-I.*include/;
        item '-DFOO=1';
        end;
      },
      'cflags',
    );
    
    my($dir) = [split /\s+/, Alien::libfoo2->cflags]->[0] =~ /^-I(.*)$/;
    
    is(
      -f File::Spec->catfile($dir,'foo.h'),
      T(),
      '-I directory points to foo.h location',
    );
  
    is(
      [split /\s+/, Alien::libfoo2->cflags_static],
      array {
        item match qr/^-I.*include/;
        item '-DFOO=1';
        item '-DFOO_STATIC=1';
        end;
      },
      'cflags_static',
    );
    
    ($dir) = [split /\s+/, Alien::libfoo2->cflags_static]->[0] =~ /^-I(.*)$/;
    
    is(
      -f File::Spec->catfile($dir,'foo.h'),
      T(),
      '-I directory points to foo.h location (static)',
    );
  };
  
  subtest 'libs' => sub {
  
    is(
      [split /\s+/, Alien::libfoo2->libs],
      array {
        item match qr/-L.*lib/;
        item '-lfoo';
        end;
      },
      'libs',
    );
    
    my($dir) = [split /\s+/, Alien::libfoo2->libs]->[0] =~ /^-L(.*)$/;
    
    is(
      -f File::Spec->catfile($dir,'libfoo.a'),
      T(),
      '-L directory points to libfoo.a location',
    );
    
    
    is(
      [split /\s+/, Alien::libfoo2->libs_static],
      array {
        item match qr/-L.*lib/;
        item '-lfoo';
        item '-lbar';
        item '-lbaz';
        end;
      },
      'libs_static',
    );
    
    ($dir) = [split /\s+/, Alien::libfoo2->libs_static]->[0] =~ /^-L(.*)$/;
    
    is(
      -f File::Spec->catfile($dir,'libfoo.a'),
      T(),
      '-L directory points to libfoo.a location (static)',
    );
  
  };
  
  is( Alien::libfoo2->version, '2.3.4', 'version' );
  
  subtest 'install type' => sub {
    is( Alien::libfoo2->install_type, 'share' );
    is( Alien::libfoo2->install_type('system'), F() );
    is( Alien::libfoo2->install_type('share'), T() );
  };
  
  is( Alien::libfoo2->config('name'), 'foo', 'config.name' );
  is( Alien::libfoo2->config('finished_installing'), T(), 'config.finished_installing' );
  
  is(
    [Alien::libfoo2->dynamic_libs],
    array {
      item match qr/libfoo.so$/;
      item match qr/libfoo.so.2$/;
      end;
    },
    'dynamic_libs',
  );
  
  is(
    [Alien::libfoo2->bin_dir],
    array {
      item T();
      end;
    },
    'bin_dir',
  );
  
  is( -f File::Spec->catfile(Alien::libfoo2->bin_dir,'foo-config'), T(), 'has a foo-config');
  
  is( Alien::libfoo2->runtime_prop->{arbitrary}, 'two', 'runtime_prop' );

};

done_testing;

package
  FFI::CheckLib;

use File::Glob qw( bsd_glob );
use File::chdir;
BEGIN { $INC{'FFI/CheckLib.pm'} = __FILE__ }

sub find_lib {
  my %args = @_;
  if($args{libpath})
  {
    return unless -d $args{libpath};
    return sort do {
      local $CWD = $args{libpath};
      map { File::Spec->rel2abs($_) } bsd_glob('*.so*');
    };
  }
  else
  {
    if($args{lib} eq 'foo')
    {
      return ('/usr/lib/libfoo.so', '/usr/lib/libfoo.so.1');
    }
    else
    {
      return;
    } 
  }
}

