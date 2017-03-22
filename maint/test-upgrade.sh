#!/bin/bash

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

# arguments: url git_tag subdir ab_git_old_tag
#
# WHERE
#
#  url - the URL to the Perl module that you want to test (either a .git repo or a .tar.gz file)
#  git_tag - the tag to checkout if using a .git repo
#  subdir - which directory in the git repository or tarball that should change into
#  ab_git_old_tag - the tag to the old version of Alien::Base

url="${1:-}"
if [ -z "$url" ]; then
  url="https://github.com/Perl5-Alien/Acme-Alien-DontPanic.git"
fi

filename=`perl -MURI -e '$url = URI->new($ARGV[0]); $url->path =~ m{^.*/(.*)$}; print $1' $url`
name=`perl -MURI -e '$url = URI->new($ARGV[0]); $url->path =~ m{^.*/(.*)\..*$}; print $1' $url`

acme_git_tag="${2:-}"

subdir="${3:-}"
if [ -z "$subdir" ]; then
  subdir=""
fi

ab_git_old_tag="${4:-}"
if [ -z "$ab_git_old_tag" ]; then
  ab_git_old_tag=0.019
fi

ab_git_new_tag=`git rev-parse HEAD`

ab_root=`pwd`
test_root=`mktemp -d -t abXXXXX`

echo "url            = $url"
echo "filename       = $filename"
echo "name           = $name"
echo "acme_git_tag   = $acme_git_tag"
echo "subdir         = $subdir"
echo "ab_root        = $ab_root"
echo "ab_git_old_tag = $ab_git_old_tag"
echo "ab_git_new_tag = $ab_git_new_tag"

cd $test_root

case $filename in

  *.git)
    git clone $url
    if [ -z "$acme_git_tag" ]; then
      cd $name
      git checkout $acme_git_tag
      cd -
    fi
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

echo "*use Alien::Base $ab_git_old_tag"

git clone $ab_root
cd "$test_root/Alien-Base"
git checkout $ab_git_old_tag
if [ -z "${PERL5LIB:-}" ]; then
  export PERL5LIB=`pwd`/lib
else
  export PERL5LIB=`pwd`/lib:$PERL5LIB
fi

cd "$test_root/$name/$subdir"

perl Build.PL

./Build

./Build test

echo "*use Alien::Base $ab_git_old_tag"
cd "$test_root/Alien-Base"
git checkout $ab_git_new_tag

cd "$test_root/$name/$subdir"

prove -bv t

