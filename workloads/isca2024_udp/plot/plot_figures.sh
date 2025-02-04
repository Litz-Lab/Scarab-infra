#!/bin/bash
set -x #echo on
cd "$(dirname "$0")"

SIM_PATH="$1"

python3 plot_eval.py -d 'fig13.json' -b baseline/32 -s $SIM_PATH
python3 plot_eval2.py -d 'fig14.15.json' -b baseline/32 -s $SIM_PATH
python3 plot_btb.py -d 'btb.json' -s $SIM_PATH
python3 plot_ftq.py -d 'ftq.json' -s $SIM_PATH
