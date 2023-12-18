#!/bin/bash
set -x

mkdir -p $HOME/cpu2017_install
mkdir -p $HOME/cpu2017
sudo mount -t iso9660 -o ro,exec,loop $HOME/cpu2017-1_0_5.iso $HOME/cpu2017_install
cd $HOME/cpu2017_install && echo "yes" | ./install.sh -d $HOME/cpu2017

mv $HOME/memtrace.cfg $HOME/cpu2017/config/memtrace.cfg
mv $HOME/compile-538-clang.sh $HOME/cpu2017/benchspec/CPU
