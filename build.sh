#!/bin/zsh
set -e
echo "Removing previous build folder"
rm -rf build/
mkdir build && cd build
echo $PWD
echo "Starting new build"
cmake -DCMAKE_CROSSCOMPILING=1 -DRUN_HAVE_STD_REGEX=0 -DRUN_HAVE_POSIX_REGEX=0 -DCMAKE_INSTALL_PREFIX=$HOME/openfhe-install ..
make -j8
make install