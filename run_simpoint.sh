#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCARABPARAMS="$4"
SEGSIZE=100000000

#
# dir for all relevant data: fingerprint, traces, log, sim stats...
mkdir -p /home/memtrace/simpoint_flow/$APPNAME
cd /home/memtrace/simpoint_flow/$APPNAME
mkdir -p fingerprint simpoints traces simulations evaluations
APPHOME=/home/memtrace/simpoint_flow/$APPNAME

# Get command to run for Spe17
if [ "$APP_GROUPNAME" == "spec2017" ]; then
  # environment
  cd /home/memtrace/cpu2017
  source ./shrc
  # compile and get command for application
  # TODO: this is just for one input
  ./bin/specperl ./bin/harness/runcpu --copies=1 --iterations=1 --threads=1 --config=memtrace --action=runsetup --size=train $APPNAME
  ogo $APPNAME run
  # TODO: the input size
  cd run_base_train*
  BINCMD=$(specinvoke -nn | tail -2 | head -1)
fi
# collect fingerprint
# TODO: add parameter: size and warm-up
fpCmd="$DYNAMORIO_HOME/bin64/drrun -opt_cleancall 2 -c /home/memtrace/libfpg.so -segment_size $SEGSIZE -- $BINCMD"
echo "generate fingerprint..."
echo "command: ${fpCmd}"
if [ "$APP_GROUPNAME" == "spec2017" ]; then
  # have to go to that dir for the spec app cmd to work
  ogo $APPNAME run
  cd run_base_train*
fi
eval $fpCmd
mv ./bbfp $APPHOME/fingerprint

# run SimPoint clustering
spCmd="/home/memtrace/simpoint -maxK 30 -fixedLength off -numInitSeeds 1000 -loadFVFile $APPHOME/fingerprint/bbfp -saveSimpoints $APPHOME/simpoints/opt.p -saveSimpointWeights $APPHOME/simpoints/opt.w -saveLabels $APPHOME/simpoints/opt.l &> $APPHOME/simpoints/simp.opt.log"
echo "cluster fingerprint..."
echo "command: ${spCmd}"
eval $spCmd

# tracing, (portablize and) raw2trace

# read in simpoint
# ref: https://stackoverflow.com/q/56005842
# map of cluster - segment
declare -A clusterMap
taskPids=()
while IFS=" " read -r segID clusterID; do
  clusterMap[$clusterID]=$segID 
  mkdir $APPHOME/traces/$clusterID
  start_inst=$(( $segID * $SEGSIZE ))
  traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces/$clusterID -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
  echo "tracing cluster ${clusterID}, segment ${segID}..."
  echo "command: ${traceCmd}"
  if [ "$APP_GROUPNAME" == "spec2017" ]; then
    # have to go to that dir for the spec app cmd to work
    ogo $APPNAME run
    cd run_base_train*
  fi
  eval $traceCmd &
  taskPids+=($!)
  sleep 2
done < $APPHOME/simpoints/opt.p

echo "wait for all tracing to finish..."
# ref: https://stackoverflow.com/a/29535256
for taskPid in ${taskPids[@]}; do
  if wait $taskPids; then
    echo "tracing process $taskPids success"
  else
    echo "tracing process $taskPids fail:"
    # # ref: https://serverfault.com/questions/479460/find-command-from-pid
    # cat /proc/${taskPids}/cmdline | xargs -0 echo
    exit
  fi
done

taskPids=()
# TODO: which dynamorio to use, release or scarab submodule?
for clusterID in "${!clusterMap[@]}"
do
  cd $APPHOME/traces/$clusterID
  mv dr*/raw/ ./raw
  mkdir -p bin
  cp raw/modules.log bin/modules.log
  cp raw/modules.log raw/modules.log.bak
  python2 /home/memtrace/scarab/utils/memtrace/portabilize_trace.py .
  cp bin/modules.log raw/modules.log
  $DYNAMORIO_HOME/tools/bin64/drraw2trace -indir ./raw/ &
  taskPids+=($!)
done

echo "wait for all raw2trace to finish..."
for taskPid in ${taskPids[@]}; do
  if wait $taskPids; then
    echo "raw2trace process $taskPids success"
  else
    echo "raw2trace process $taskPids fail:"
    # # ref https://serverfault.com/questions/479460/find-command-from-pid
    # cat /proc/${taskPids}/cmdline | xargs -0 echo
    exit
  fi
done

# map of trace file
declare -A traceMap
for clusterID in "${!clusterMap[@]}"
do
  # traceMap[$clusterID]=(ls $APPHOME/traces/$clusterID/trace/)
  traceMap[$clusterID]=$(ls $APPHOME/traces/$clusterID/trace/)
  # TODO: make sure one trace file
done

taskPids=()
# simulation in parallel -> use map of trace file
for clusterID in "${!traceMap[@]}"
do
  mkdir $APPHOME/simulations/$clusterID
  cp /home/memtrace/scarab/src/PARAMS.sunny_cove $APPHOME/simulations/$clusterID/PARAMS.in
  cd $APPHOME/simulations/$clusterID
  scarabCmd="/home/memtrace/scarab/src/scarab --frontend memtrace --cbp_trace_r0=$APPHOME/traces/$clusterID/trace/${traceMap[$clusterID]} --memtrace_modules_log=$APPHOME/traces/$clusterID/raw/ $SCARABPARAMS &> sim.log"
  echo "simulating cluster ${clusterID}..."
  echo "command: ${scarabCmd}"
  eval $scarabCmd &
  taskPids+=($!)
done

echo "wait for all simulations to finish..."
for taskPid in ${taskPids[@]}; do
  if wait $taskPids; then
    echo "simulation process $taskPids success"
  else
    echo "simulation process $taskPids fail:"
    # # ref https://serverfault.com/questions/479460/find-command-from-pid
    # cat /proc/${taskPids}/cmdline | xargs -0 echo
    exit
  fi
done