package Alien::Base::ModuleBuild::Repository::Test;

use strict;
use warnings;

use parent 'Alien::Base::ModuleBuild::Repository';

sub list_files {
  my $self = shift;
  #files from GNU GSL FTP server, fetched 1/24/2012
  my @files = ( qw/
    gsl-1.0-gsl-1.1.patch.gz
    gsl-1.0.tar.gz
    gsl-1.1-gsl-1.1.1.patch.gz
    gsl-1.1.1-gsl-1.2.patch.gz
    gsl-1.1.1.tar.gz
    gsl-1.1.tar.gz
    gsl-1.10-1.11.patch.gz
    gsl-1.10-1.11.patch.gz.sig
    gsl-1.10.tar.gz
    gsl-1.10.tar.gz.sig
    gsl-1.11-1.12.patch.gz
    gsl-1.11-1.12.patch.gz.sig
    gsl-1.11.tar.gz
    gsl-1.11.tar.gz.sig
    gsl-1.12-1.13.patch.gz
    gsl-1.12-1.13.patch.gz.sig
    gsl-1.12.tar.gz
    gsl-1.12.tar.gz.sig
    gsl-1.13-1.14.patch.gz
    gsl-1.13-1.14.patch.gz.sig
    gsl-1.13.tar.gz
    gsl-1.13.tar.gz.sig
    gsl-1.14.tar.gz
    gsl-1.14.tar.gz.sig
    gsl-1.15.tar.gz
    gsl-1.15.tar.gz.sig
    gsl-1.2-gsl-1.3.patch.gz
    gsl-1.2.tar.gz
    gsl-1.3-gsl-1.4.patch.gz
    gsl-1.3-gsl-1.4.patch.gz.asc
    gsl-1.3.tar.gz
    gsl-1.4-gsl-1.5.patch.gz
    gsl-1.4-gsl-1.5.patch.gz.sig
    gsl-1.4.tar.gz
    gsl-1.4.tar.gz.asc
    gsl-1.5-gsl-1.6.patch.gz
    gsl-1.5-gsl-1.6.patch.gz.sig
    gsl-1.5.tar.gz
    gsl-1.5.tar.gz.sig
    gsl-1.6-gsl-1.7.patch.gz
    gsl-1.6-gsl-1.7.patch.gz.sig
    gsl-1.6.tar.gz
    gsl-1.6.tar.gz.sig
    gsl-1.7-1.8.patch.gz
    gsl-1.7-1.8.patch.gz.sig
    gsl-1.7.tar.gz
    gsl-1.7.tar.gz.sig
    gsl-1.8-1.9.patch.gz
    gsl-1.8-1.9.patch.gz.sig
    gsl-1.8.tar.gz
    gsl-1.8.tar.gz.sig
    gsl-1.9-1.10.patch.gz
    gsl-1.9-1.10.patch.gz.sig
    gsl-1.9.tar.gz
    gsl-1.9.tar.gz.sig
  / );

  return @files;
}

1;

