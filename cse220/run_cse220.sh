#!/bin/bash
set -x #echo on

APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCENARIONUM="$4"
SCARABPARAMS="$5"
# this is fixed/settled for NON trace post-processing flow.
# for trace post-processing flow, SEGSIZE is read from file
SEGSIZE=100000000
SCARABMODE="$6"
SCARABARCH="$7"
# 10M warmup by default
WARMUP=10000000

if [ "$SCARABMODE" -ne 220 ]; then
  echo "Use -s 220"
  exit 1
fi

declare -A trace_num

trace_num["500.perlbench_r"]="12569"
trace_num["502.gcc_r"]="35835"
trace_num["503.bwaves_r"]="14021"
trace_num["505.mcf_r"]="26322"
trace_num["507.cactuBSSN_r"]="430"
trace_num["508.namd_r"]="152234"
trace_num["510.parest_r"]="157069"
trace_num["511.povray_r"]="77803"
trace_num["519.lbm_r"]="34969"
trace_num["520.omnetpp_r"]="93640"
trace_num["521.wrf_r"]="5637"
trace_num["523.xalancbmk_r"]="7528"
trace_num["525.x264_r"]="165858"
trace_num["526.blender_r"]="63365"
trace_num["527.cam4_r"]="125439"
trace_num["531.deepsjeng_r"]="76011"
trace_num["538.imagick_r"]="204585"
trace_num["541.leela_r"]="124510"
trace_num["544.nab_r"]="89675"
trace_num["548.exchange2_r"]="121021"
trace_num["549.fotonik3d_r"]="65898"
trace_num["554.roms_r"]="112106"
trace_num["557.xz_r"]="34585"

MODULESDIR=/cse220_traces/$APPNAME/traces_simp/${trace_num[${APPNAME}]}/raw
TRACEFILE=/cse220_traces/$APPNAME/traces_simp/${trace_num[${APPNAME}]}/trace/${trace_num[${APPNAME}]}.zip
echo $MODULESDIR
echo $TRACEFILE

SCARABHOME=$HOME/scarab/
SIMHOME=$HOME/exp/simulations/$APPNAME
mkdir -p $SIMHOME
TRACEHOME=/cse220_traces/$APPNAME

################################################################
# trace-based simulations
taskPids=()
start=`date +%s`
mkdir -p $SIMHOME/$SCENARIONUM
cp $SCARABHOME/src/PARAMS.$SCARABARCH $SIMHOME/$SCENARIONUM/PARAMS.in
cd $SIMHOME/$SCENARIONUM
scarabCmd="$SCARABHOME/src/scarab --frontend memtrace --cbp_trace_r0 $TRACEFILE --memtrace_modules_log $MODULESDIR --memtrace_roi_begin 1 --memtrace_roi_end 20000000 --inst_limit 20000000 --full_warmup $WARMUP --use_fetched_count=0 $SCARABPARAMS &> sim.log"
echo "simulating ..."
echo "command: ${scarabCmd}"
eval $scarabCmd &
taskPids+=($!)

echo "wait for all simulations to finish..."
for taskPid in ${taskPids[@]}; do
  if wait $taskPid; then
    echo "simulation process $taskPid success"
  else
    echo "simulation process $taskPid fail"
    exit
  fi
done
end=`date +%s`
runtime=$((end-start))
hours=$((runtime / 3600));
minutes=$(( (runtime % 3600) / 60 ));
seconds=$(( (runtime % 3600) % 60 ));
echo "simulation Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

################################################################