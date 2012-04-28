#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;

use File::chdir;
use File::Spec;
use File::Copy qw/copy/;

use ExtUtils::LibBuilder;

my $config_file = 'config';
my $base_config = {
  clean => {
     src => [], 
     '.' => [$config_file],
  },
  install => {
    lib     => [],
    include => [qw/libdontpanic.h/],
  },
};

my $prefix = $CWD;
GetOptions(
  'prefix=s' => \$prefix,
);

my $action = shift || 'build';

my $config = _load_options();

$config->{prefix} ||= $prefix;

my $sub = __PACKAGE__->can($action) or die "Unknown action: $action";
$sub->();

sub build {
  {
    local $CWD = 'src';

    my $libbuilder = ExtUtils::LibBuilder->new() or die "EU::LibBuilder object creation failed";

    # Compile
    my $o = $libbuilder->compile(
      source => 'libdontpanic.c',
      extra_compiler_flags => ['-fPIC'],
    );
    push @{ $config->{clean}{src} }, $o;

    # Link
    my $lib = $libbuilder->link(
      objects => [ $o ],
    );
    push @{ $config->{clean}{src} }, $lib;
    push @{ $config->{install}{lib} }, $lib;
  }

  _store_options($config);
}

sub configure {
  local $base_config->{prefix} = $prefix;
  _store_options( $base_config );
}

sub install {
  my %files = do {
    local $CWD = 'src';
    map {
      my $folder = $_;
      my @files = map {File::Spec->rel2abs($_)} @{$config->{install}{$folder}};
      ($folder, \@files)
    } keys %{ $config->{install} };
  };

  _check_mkdir($config->{prefix});
  local $CWD = $config->{prefix};

  foreach my $folder (keys %files) {
    _check_mkdir($folder);
    local $CWD = $folder;
    foreach my $file (@{$files{$folder}}) {
      copy $file, $CWD or die "Could not copy file $file";
    }
    _write_pc() if $folder eq 'lib';
  }

}

sub clean {
  foreach my $folder (keys %{$config->{clean}}) {
    local $CWD = $folder;
    unlink @{$config->{clean}{$folder}};
  }
}

sub _load_options {
  return $base_config unless -e $config_file;

  my $config = do $config_file;
  return $config;
}

sub _store_options {
  my $opts = shift;
  open my $fh, '>', $config_file;
  print $fh Dumper $opts;
}

sub _write_pc {
  open my $fh, '>', 'dontpanic.pc';

  my $prefix = $config->{prefix};

  print $fh <<END_PC;
prefix=$prefix
libdir=$prefix/lib
includedir=$prefix/include

Name: DontPanic
Description: Test Library for Alien::Base
Version: 1.01
Libs: -L$prefix/lib -ldontpanic
Cflags: -I$prefix/include
END_PC
}

sub _check_mkdir {
  my $folder = shift;
  unless (-d $folder) {
    mkdir $folder or die "Could not create folder: $folder";
  }
}

