#!/bin/bash
set -x

mkdir -p /home/dcuser/cpu2017_install
mkdir -p /home/dcuser/cpu2017
echo "dcuser" | sudo -S mount -t iso9660 -o ro,exec,loop /home/dcuser/cpu2017-1_0_5.iso /home/dcuser/cpu2017_install
cd /home/dcuser/cpu2017_install && echo "yes" | ./install.sh -d /home/dcuser/cpu2017

mv /home/dcuser/memtrace.cfg /home/dcuser/cpu2017/config/memtrace.cfg
mv /home/dcuser/compile-538-clang.sh /home/dcuser/cpu2017/benchspec/CPU
