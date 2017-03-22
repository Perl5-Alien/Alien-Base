package Alien::Foo2::ConfigData;
use strict;
my $arrayref = eval do {local $/; <DATA>}
  or die "Couldn't load ConfigData data: $@";
close DATA;
my ($config, $features, $auto_features) = @$arrayref;

sub config { $config->{$_[1]} }

sub set_config { $config->{$_[1]} = $_[2] }
sub set_feature { $features->{$_[1]} = 0+!!$_[2] }  # Constrain to 1 or 0

sub auto_feature_names { grep !exists $features->{$_}, keys %$auto_features }

sub feature_names {
  my @features = (keys %$features, auto_feature_names());
  @features;
}

sub config_names  { keys %$config }

sub write {
  my $me = __FILE__;

  # Can't use Module::Build::Dumper here because M::B is only a
  # build-time prereq of this module
  require Data::Dumper;

  my $mode_orig = (stat $me)[2] & 07777;
  chmod($mode_orig | 0222, $me); # Make it writeable
  open(my $fh, '+<', $me) or die "Can't rewrite $me: $!";
  seek($fh, 0, 0);
  while (<$fh>) {
    last if /^__DATA__$/;
  }
  die "Couldn't find __DATA__ token in $me" if eof($fh);

  seek($fh, tell($fh), 0);
  my $data = [$config, $features, $auto_features];
  print($fh 'do{ my '
	      . Data::Dumper->new([$data],['x'])->Purity(1)->Dump()
	      . '$x; }' );
  truncate($fh, tell($fh));
  close $fh;

  chmod($mode_orig, $me)
    or warn "Couldn't restore permissions on $me: $!";
}

sub feature {
  my ($package, $key) = @_;
  return $features->{$key} if exists $features->{$key};

  my $info = $auto_features->{$key} or return 0;

  # Under perl 5.005, each(%$foo) isn't working correctly when $foo
  # was reanimated with Data::Dumper and eval().  Not sure why, but
  # copying to a new hash seems to solve it.
  my %info = %$info;

  require Module::Build;  # XXX should get rid of this
  while (my ($type, $prereqs) = each %info) {
    next if $type eq 'description' || $type eq 'recommends';

    my %p = %$prereqs;  # Ditto here.
    while (my ($modname, $spec) = each %p) {
      my $status = Module::Build->check_installed_status($modname, $spec);
      if ((!$status->{ok}) xor ($type =~ /conflicts$/)) { return 0; }
      if ( ! eval "require $modname; 1" ) { return 0; }
    }
  }
  return 1;
}

__DATA__
do{ my $x = [
       {
         'alien_version' => undef,
         'ffi_name' => undef,
         'finished_installing' => 1,
         'inline_auto_include' => [],
         'install_type' => 'share',
         'msys' => 0,
         'name' => 'libfoo2',
         'original_prefix' => '/home/user/.cpanm/work/1456299506.4021/Alien-Foo2-0.12/blib/lib/auto/share/dist/Alien-Foo2',
         'pkgconfig' => {
                          '_manual' => bless( {
                                                'keywords' => {
                                                                'Cflags' => '-I${pcfiledir}/lib/libfoo2-3.2.1/include',
                                                                'Libs' => '-L${pcfiledir}/lib -lfoo2',
                                                                'Version' => ''
                                                              },
                                                'package' => 'libfoo2',
                                                'vars' => {
                                                            'pcfiledir' => '/home/user/.cpanm/work/1456299506.4021/Alien-Foo2-0.12/blib/lib/auto/share/dist/Alien-Foo2'
                                                          }
                                              }, 'Alien::Base::PkgConfig' ),
                          'libfoo2' => bless( {
                                               'keywords' => {
                                                               'Cflags' => '-I${includedir}',
                                                               'Description' => 'Library supporting Foreign Function Interfaces',
                                                               'Libs' => '-L${toolexeclibdir} -lfoo2',
                                                               'Name' => 'libfoo2',
                                                               'Version' => '3.2.1'
                                                             },
                                               'package' => 'libfoo2',
                                               'vars' => {
                                                           'exec_prefix' => '${prefix}',
                                                           'includedir' => '${libdir}/libfoo2-3.2.1/include',
                                                           'libdir' => '${exec_prefix}/lib',
                                                           'pcfiledir' => '/home/user/.cpanm/work/1456299506.4021/Alien-Foo2-0.12/_alien/libfoo2-3.2.1',
                                                           'prefix' => '/home/user/.cpanm/work/1456299506.4021/Alien-Foo2-0.12/blib/lib/auto/share/dist/Alien-Foo2',
                                                           'toolexeclibdir' => '${exec_prefix}/lib/../lib'
                                                         }
                                             }, 'Alien::Base::PkgConfig' )
                        },
         'version' => '3.2.1',
         'working_directory' => '/home/user/.cpanm/work/1456299506.4021/Alien-Foo2-0.12/_alien/libfoo2-3.2.1'
       },
       {},
       {}
     ];
$x; }
