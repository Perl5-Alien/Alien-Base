#!/bin/bash

test_root=`mktemp -d`
export SHELL=/bin/sh
mkdir "$test_root/perl5"
eval "$(perl -Mlocal::lib=$test_root/perl5)"

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

git clone --depth 2 https://github.com/Perl5-Alien/Acme-Alien-DontPanic.git
git clone --depth 2 https://github.com/Perl5-Alien/Acme-Ford-Prefect.git
git clone --depth 2 https://github.com/Perl5-Alien/Acme-Ford-Prefect-FFI.git

cd "$test_root/Acme-Alien-DontPanic"
perl Build.PL
./Build
./Build test verbose=1
./Build install --destdir "$test_root/destdir"

(cd $test_root/destdir/$test_root/perl5/ && tar cvf - *) | (cd $test_root/perl5 && tar xvf -)

cd "$test_root/Acme-Ford-Prefect"
perl Build.PL
./Build
./Build test verbose=1

cd "$test_root"
cd "$test_root/Acme-Ford-Prefect-FFI"
perl Build.PL
./Build
./Build test verbose=1
