#!/bin/bash

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
    git clone --depth 2 https://github.com/Perl5-Alien/Acme-Alien-DontPanic.git
    cd Acme-Alien-DontPanic
    echo "+cpanm $location -v ."
    cpanm $location -v .
    ;;

  Acme::Ford::Prefect)
    cd `mktemp -d`
    git clone --depth 2 https://github.com/Perl5-Alien/Acme-Ford-Prefect.git
    cd Acme-Ford-Prefect
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
