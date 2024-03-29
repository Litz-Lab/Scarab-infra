#!/bin/bash
set -x #echo on
cd "$(dirname "$0")"

SIM_PATH="$1"

python plot_eval.py -d 'fig13.json' -b baseline/32 -s $SIM_PATH
python plot_eval2.py -d 'fig14.15.json' -b baseline/32 -s $SIM_PATH
python plot_btb.py -d 'btb.json' -s $SIM_PATH
python plot_ftq.py -d 'ftq.json' -s $SIM_PATH
