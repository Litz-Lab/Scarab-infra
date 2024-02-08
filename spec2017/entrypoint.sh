#!/bin/bash
set -x

mkdir -p $tmpdir/cpu2017_install
sudo mount -t iso9660 -o ro,exec,loop $tmpdir/cpu2017-1_0_5.iso $tmpdir/cpu2017_install
