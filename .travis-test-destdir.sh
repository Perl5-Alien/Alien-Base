#!/bin/bash

test_root=`mktemp -d`
export SHELL=/bin/sh
mkdir "$test_root/perl5"
eval "$(perl -Mlocal::lib=$test_root/perl5)"

# bash strict (see http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Test:
#
#  1. use existing version of Alien::Base (whatever is arleady installed)
#  2. Build Acme::Alien::DontPanic
#  3. Install Acme::Alien::DontPanic with --destdir
#  4. Move target ($destdir/$target => $target)
#  5. Build and test Acme::Ford::Prefect and Acme::Ford::Prefect::FFI

cd $test_root

git clone https://github.com/Perl5-Alien/Alien-Base-Extras.git
cd "$test_root/Alien-Base-Extras/Acme-Alien-DontPanic"
perl Build.PL
./Build
./Build test
./Build install --destdir "$test_root/destdir"

mv $test_root/destdir/$test_root/perl5/* $test_root/perl5

cd "$test_root/Alien-Base-Extras/Acme-Ford-Prefect"
perl Build.PL
./Build
./Build test

cd "$test_root"
git clone https://github.com/Perl5-Alien/Acme-Ford-Prefect-FFI.git
cd "$test_root/Acme-Ford-Prefect-FFI"
perl Build.PL
./Build
./Build test
