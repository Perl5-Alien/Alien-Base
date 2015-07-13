#!/bin/sh

# bash strict (see http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

if [ "$ALIEN_FORCE" == "0" ]; then

  cd `mktemp -d`
  wget http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz
  tar xf autoconf-2.69.tar.gz
  cd autoconf-2.69
  ./configure --prefix=$HOME/travislocal
  make
  make install

  cd `mktemp -d`
  git clone https://github.com/Perl5-Alien/Alien-Base-Extras.git
  tar xf Alien-Base-Extras/Acme-Alien-DontPanic/inc/dontpanic-1.0.tar.gz
  cd dontpanic-1.0
  ./configure --prefix=$HOME/travislocal
  make
  make install

fi
