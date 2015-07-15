#!/bin/bash

# bash strict (see http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Test:
#
#  1. Install old verson of Alien::Base
#  2. Build an alien dist (defaults to Acme::Alien::DontPanic out of git)
#  3. test that dist
#  4. Upgrade to current version of Alien::Base
#  5. run test tests again
#
# The defaults check a specific regression that happened between 0.019 and 0.020 where
# the format in ConfigData.pm changed.  I expect this script should be used to verify
# the goodness of any future change to the format of the data in ConfigData.pm in the
# future, but it does require the attention of developers to recognize this danger and
# add the appropriate test to the .travis.yml

# arguments: url git_tag subdir old_ab_url
#
# WHERE
#
#  url - the URL to the Perl module that you want to test (either a .git repo or a .tar.gz file)
#  git_tag - the tag to checkout if using a .git repo
#  subdir - which directory in the git repository or tarball that should change into
#  old_module_build_url - URL to the old version of Alien::Base

url="${1:-}"
if [ -z "$url" ]; then
  url="https://github.com/Perl5-Alien/Alien-Base-Extras.git"
fi

filename=`perl -MURI -e '$url = URI->new($ARGV[0]); $url->path =~ m{^.*/(.*)$}; print $1' $url`
name=`perl -MURI -e '$url = URI->new($ARGV[0]); $url->path =~ m{^.*/(.*)\..*$}; print $1' $url`

git_tag="${2:-}"
if [ -z "$git_tag" ]; then
  git_tag="d2d6e3782bfdbec14db2c78532122055d2b22401"
fi

subdir="${3:-}"
if [ -z "$subdir" ]; then
  subdir="Acme-Alien-DontPanic"
fi

old_ab_url="${4:-}"
if [ -z "$old_ab_url" ]; then
  old_ab_url="https://cpan.metacpan.org/authors/id/P/PL/PLICEASE/Alien-Base-0.019.tar.gz"
fi

echo "url        = $url"
echo "filename   = $filename"
echo "name       = $name"
echo "subdir     = $subdir"
echo "old AB URL = $old_ab_url"

ab_root=`pwd`
test_root=`mktemp -d`

mkdir "$test_root/perl5"
SHELL=/bin/sh
eval "$(perl -Mlocal::lib=$test_root/perl5)"

cd $test_root

case $filename in

  *.git)
    git clone $url
    cd $name
    git checkout $git_tag
    cd -
    ;;

  *.tar)
    wget $url
    tar xf $filename
    ;;

  *)
    echo do not know that extension.
    exit 2
    ;;

esac

cd "$name/$subdir"

echo "+cpanm $old_ab_url"
cpanm $old_ab_url

echo "+perl Build.PL"
perl Build.PL || exit 2

echo "+./Build"
./Build || exit 2

#echo "+prove -b t"
#prove -l t || exit 2

echo "+./Build test"
./Build test || exit 2

echo "+cpanm $ab_root"
cd $ab_root
cpanm . || exit 2
cd -

echo "+prove -bv t"
prove -bv t || exit 2

