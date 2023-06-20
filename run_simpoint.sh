#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCARABPARAMS="$4"
SEGSIZE=100000000
TRACE_BASED="$5"

# dir for all relevant data: fingerprint, traces, log, sim stats...
mkdir -p /home/memtrace/simpoint_flow/$APPNAME
cd /home/memtrace/simpoint_flow/$APPNAME
mkdir -p fingerprint simpoints traces simulations evaluations
APPHOME=/home/memtrace/simpoint_flow/$APPNAME

# Get command to run for Spe17
if [ "$APP_GROUPNAME" == "spec2017_a" ]; then
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
  for sub in $BINCMD; do
    if [[ -f $sub ]]; then
      # ref
      # https://stackoverflow.com/a/13210909
      # https://stackoverflow.com/a/7126780
      replace=$(readlink -f "$sub")
      BINCMD="${BINCMD/"$sub"/"$replace"}"
    fi
  done
fi

################################################################

# collect fingerprint
# TODO: add parameter: size and warm-up
cd $APPHOME/fingerprint
fpCmd="$DYNAMORIO_HOME/bin64/drrun -opt_cleancall 2 -c /home/memtrace/libfpg.so -segment_size $SEGSIZE -- $BINCMD"
echo "generate fingerprint..."
echo "command: ${fpCmd}"
# if [ "$APP_GROUPNAME" == "spec2017" ]; then
#   # have to go to that dir for the spec app cmd to work
#   ogo $APPNAME run
#   cd run_base_train*
# fi

# ref: https://unix.stackexchange.com/a/52347
start=`date +%s`
eval $fpCmd
end=`date +%s`
runtime=$((end-start))
hours=$((runtime / 3600));
minutes=$(( (runtime % 3600) / 60 ));
seconds=$(( (runtime % 3600) % 60 ));
echo "fingerprint Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

# mv ./bbfp $APPHOME/fingerprint

################################################################

# run SimPoint clustering
wc_result=($(wc $APPHOME/fingerprint/bbfp))
lines=${wc_result[0]}
# round to nearest int
maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
echo "fingerprint size: $lines, maxk: $maxK"
spCmd="/home/memtrace/simpoint -maxK $maxK -fixedLength off -numInitSeeds 1000 -loadFVFile $APPHOME/fingerprint/bbfp -saveSimpoints $APPHOME/simpoints/opt.p -saveSimpointWeights $APPHOME/simpoints/opt.w -saveLabels $APPHOME/simpoints/opt.l &> $APPHOME/simpoints/simp.opt.log"
echo "cluster fingerprint..."
echo "command: ${spCmd}"

start=`date +%s`
eval $spCmd
end=`date +%s`
runtime=$((end-start))
hours=$((runtime / 3600));
minutes=$(( (runtime % 3600) / 60 ));
seconds=$(( (runtime % 3600) % 60 ));
echo "clustering Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

################################################################
# read in simpoint
# ref: https://stackoverflow.com/q/56005842
# map of cluster - segment
declare -A clusterMap
while IFS=" " read -r segID clusterID; do
  clusterMap[$clusterID]=$segID 
done < $APPHOME/simpoints/opt.p

################################################################
# trace-based simulations

if [ "$TRACE_BASED" == "true" ]; then
  # tracing, raw2trace
  taskPids=()
  start=`date +%s`
  for clusterID in "${!clusterMap[@]}"
  do
    mkdir -p $APPHOME/traces/$clusterID
    cd $APPHOME/traces/$clusterID
    segID=${clusterMap[$clusterID]}
    start_inst=$(( $segID * $SEGSIZE ))
    traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces/$clusterID -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
    echo "tracing cluster ${clusterID}, segment ${segID}..."
    echo "command: ${traceCmd}"
    # if [ "$APP_GROUPNAME" == "spec2017" ]; then
    #   # have to go to that dir for the spec app cmd to work
    #   ogo $APPNAME run
    #   cd run_base_train*
    # fi
    eval $traceCmd &
    taskPids+=($!)
    sleep 2
  done

  echo "wait for all tracing to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "tracing process $taskPid success"
    else
      echo "tracing process $taskPid fail"
      # # ref: https://serverfault.com/questions/479460/find-command-from-pid
      # cat /proc/${taskPid}/cmdline | xargs -0 echo
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
    echo "memtrace" | sudo -S python2 /home/memtrace/scarab/utils/memtrace/portabilize_trace.py .
    cp bin/modules.log raw/modules.log
    $DYNAMORIO_HOME/tools/bin64/drraw2trace -indir ./raw/ &
    taskPids+=($!)
    sleep 2
  done

  echo "wait for all raw2trace to finish..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "raw2trace process $taskPid success"
    else
      echo "raw2trace process $taskPid fail"
      # # ref https://serverfault.com/questions/479460/find-command-from-pid
      # cat /proc/${taskPid}/cmdline | xargs -0 echo
      exit
    fi
  done
  end=`date +%s`
  runtime=$((end-start))
  hours=$((runtime / 3600));
  minutes=$(( (runtime % 3600) / 60 ));
  seconds=$(( (runtime % 3600) % 60 ));
  echo "tracing Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

  ################################################################

  # map of trace file
  declare -A traceMap
  for clusterID in "${!clusterMap[@]}"
  do
    # traceMap[$clusterID]=(ls $APPHOME/traces/$clusterID/trace/)
    traceMap[$clusterID]=$(ls $APPHOME/traces/$clusterID/trace/window.0000)
    # TODO: make sure one trace file
  done
fi

################################################################
# trace-based or exec-driven simulations
taskPids=()

start=`date +%s`
# simulation in parallel -> use map of trace file
for clusterID in "${!clusterMap[@]}"
do
  mkdir -p $APPHOME/simulations/$clusterID
  cp /home/memtrace/scarab/src/PARAMS.kaby_lake $APPHOME/simulations/$clusterID/PARAMS.in
  cd $APPHOME/simulations/$clusterID
  if [ "$TRACE_BASED" == "true" ]; then
    scarabCmd="/home/memtrace/scarab/src/scarab --frontend memtrace --fetch_off_path_ops 0 --cbp_trace_r0=$APPHOME/traces/$clusterID/trace/window.0000/${traceMap[$clusterID]} --memtrace_modules_log=$APPHOME/traces/$clusterID/raw/ $SCARABPARAMS &> sim.log"
  else
    segID=${clusterMap[$clusterID]}
    start_inst=$(( $segID * $SEGSIZE ))
    scarabCmd="
    python3 /home/memtrace/scarab/bin/scarab_launch.py --program=\"$BINCMD\" \
    --simdir=\"$APPHOME/simulations/$clusterID\" \
    --pintool_args=\"-hyper_fast_forward_count $start_inst\" \
    --scarab_args=\"--inst_limit $SEGSIZE $SCARABPARAMS\" \
    --scarab_stdout=\"$APPHOME/simulations/$clusterID/scarab.out\" \
    --scarab_stderr=\"$APPHOME/simulations/$clusterID/scarab.err\" \
    --pin_stdout=\"$APPHOME/simulations/$clusterID/pin.out\" \
    --pin_stderr=\"$APPHOME/simulations/$clusterID/pin.err\" \
    "
  fi
  echo "simulating cluster ${clusterID}..."
  echo "command: ${scarabCmd}"
  eval $scarabCmd &
  taskPids+=($!)
done

echo "wait for all simulations to finish..."
for taskPid in ${taskPids[@]}; do
  if wait $taskPid; then
    echo "simulation process $taskPid success"
  else
    echo "simulation process $taskPid fail"
    # # ref https://serverfault.com/questions/479460/find-command-from-pid
    # cat /proc/${taskPid}/cmdline | xargs -0 echo
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