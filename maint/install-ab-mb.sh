#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

git clone https://github.com/Perl5-Alien/Alien-Base-ModuleBuild.git /tmp/Alien-Base-ModuleBuild
cd /tmp/Alien-Base-ModuleBuild
cpanm -n -v .
