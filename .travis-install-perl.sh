#!/bin/sh

# bash strict (see http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

mod="${1:-}"

if [ -z "$mod" ]; then
  mod="nil"
fi

location="${2:-}"

if [ ! -z "$location" ]; then
  location="-l$location"
fi


case $mod in

  Acme::Alien::DontPanic)
    cd `mktemp -d`
    git clone https://github.com/Perl5-Alien/Alien-Base-Extras.git
    cd Alien-Base-Extras/Acme-Alien-DontPanic
    echo "+cpanm $location -v ."
    cpanm $location -v .
    ;;

  Acme::Ford::Prefect)
    cd `mktemp -d`
    git clone https://github.com/Perl5-Alien/Alien-Base-Extras.git
    cd Alien-Base-Extras/Acme-Ford-Prefect
    echo "+cpanm $location -v ."
    cpanm $location -v .
    ;;

  nil)
    echo "you did not specify a module";
    exit 2;
    ;;

  *)
    echo "+cpanm $location -v $mod";
    cpanm $location -v $mod
    ;;

esac
