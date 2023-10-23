#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCENARIONUM="$4"
SCARABPARAMS="$5"
SEGSIZE=100000000
SCARABMODE="$6"

# Get command to run for Spe17
if [ "$APP_GROUPNAME" == "spec2017" ]; then
  # environment
  cd /home/dcuser/cpu2017
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

if [ "$SCARABMODE" == "3" ] || [ "$SCARABMODE" == "4" ]; then
  cd /home/dcuser/simpoint_flow/$APPNAME
  mkdir -p simulations evaluations
  APPHOME=/home/dcuser/simpoint_flow/$APPNAME
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

  if [ "$SCARABMODE" == "4" ]; then
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
    mkdir -p $APPHOME/simulations/$SCENARIONUM/$clusterID
    cp /home/dcuser/scarab/src/PARAMS.sunny_cove $APPHOME/simulations/$SCENARIONUM/$clusterID/PARAMS.in
    cd $APPHOME/simulations/$SCENARIONUM/$clusterID
    if [ "$SCARABMODE" == "4" ]; then
      scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace --cbp_trace_r0=$APPHOME/traces/$clusterID/trace/window.0000/${traceMap[$clusterID]} --memtrace_modules_log=$APPHOME/traces/$clusterID/raw/ $SCARABPARAMS &> sim.log"
    else
      segID=${clusterMap[$clusterID]}
      start_inst=$(( $segID * $SEGSIZE ))
      scarabCmd="
      python3 /home/dcuser/scarab/bin/scarab_launch.py --program=\"$BINCMD\" \
      --simdir=\"$APPHOME/simulations/$SCENARIONUM/$clusterID\" \
      --pintool_args=\"-hyper_fast_forward_count $start_inst\" \
      --scarab_args=\"--inst_limit $SEGSIZE $SCARABPARAMS\" \
      --scarab_stdout=\"$APPHOME/simulations/$SCENARIONUM/$clusterID/scarab.out\" \
      --scarab_stderr=\"$APPHOME/simulations/$SCENARIONUM/$clusterID/scarab.err\" \
      --pin_stdout=\"$APPHOME/simulations/$SCENARIONUM/$clusterID/pin.out\" \
      --pin_stderr=\"$APPHOME/simulations/$SCENARIONUM/$clusterID/pin.err\" \
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
elif [ "$SCARABMODE" == "1" ] || [ "$SCARABMODE" == "2" ]; then
  cd /home/dcuser/nonsimpoint_flow/$APPNAME
  mkdir -p simulations evaluations
  APPHOME=/home/dcuser/nonsimpoint_flow/$APPNAME

  if [ "$SCARABMODE" == "2" ]; then
    traceMap=$(ls $APPHOME/traces/trace/)
  fi
  ################################################################
  # trace-based or exec-driven simulations
  taskPids=()
  start=`date +%s`
  mkdir -p $APPHOME/simulations/$SCENARIONUM
  cp /home/dcuser/scarab/src/PARAMS.sunny_cove $APPHOME/simulations/$SCENARIONUM/PARAMS.in
  cd $APPHOME/simulations/$SCENARIONUM
  if [ "$SCARABMODE" == "2" ]; then
    scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace --cbp_trace_r0=$APPHOME/traces/trace/${traceMap} --memtrace_modules_log=$APPHOME/traces/raw/ $SCARABPARAMS &> sim.log"
  else
    start_inst=100000000
    scarabCmd="
    python3 /home/dcuser/scarab/bin/scarab_launch.py --program=\"$BINCMD\" \
      --simdir=\"$APPHOME/simulations/$SCENARIONUM/\" \
      --pintool_args=\"-hyper_fast_forward_count $start_inst\" \
      --scarab_args=\"--inst_limit $SEGSIZE $SCARABPARAMS\" \
      --scarab_stdout=\"$APPHOME/simulations/$SCENARIONUM/scarab.out\" \
      --scarab_stderr=\"$APPHOME/simulations/$SCENARIONUM/scarab.err\" \
      --pin_stdout=\"$APPHOME/simulations/$SCENARIONUM/pin.out\" \
      --pin_stderr=\"$APPHOME/simulations/$SCENARIONUM/pin.err\" \
      "
  fi
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
fi