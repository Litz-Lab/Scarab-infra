#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCENARIONUM="$4"
SCARABPARAMS="$5"
SEGSIZE=100000000
TRACE_BASED="$6"

# dir for all relevant data: traces, log, sim stats...
mkdir -p /home/dcuser/nonsimpoint_flow/$APPNAME
cd /home/dcuser/nonsimpoint_flow/$APPNAME
mkdir -p traces simulations evaluations
APPHOME=/home/dcuser/nonsimpoint_flow/$APPNAME

################################################################
# trace-based simulations

if [ "$TRACE_BASED" == "true" ]; then
  # tracing, raw2trace
  taskPids=()
  start=`date +%s`
  mkdir -p $APPHOME/traces
  cd $APPHOME/traces
  start_inst=100000000

  case $APPNAME in
    cassandra | kafka | tomcat)
      # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
      traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
      ;;
    chirper | http)
      # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
      traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
      ;;
    solr)
      # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
      # https://github.com/DynamoRIO/dynamorio/commits/i3733-jvm-bug-fixes does not work: "DynamoRIO Cache Simulator Tracer interval crash at PC 0x00007fe16d8e8fdb. Please report this at https://dynamorio.org/issues"
      # Scarab does not work either: "setarch: failed to set personality to x86_64: Operation not permitted"
      # Solr uses many threads and seems to run too long on simpoint's fingerprint collection
      traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
      ;;
    *)
      traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -trace_for_instrs $SEGSIZE -- ${BINCMD}"
      ;;
  esac
  echo "tracing ..."
  echo "command: ${traceCmd}"
  eval $traceCmd &
  taskPids+=($!)
  sleep 2

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
  cd $APPHOME/traces
  mv dr*/raw/ ./raw
  mkdir -p bin
  cp raw/modules.log bin/modules.log
  cp raw/modules.log raw/modules.log.bak
  echo "memtrace" | sudo -S python2 /home/dcuser/scarab/utils/memtrace/portabilize_trace.py .
  cp bin/modules.log raw/modules.log
  $DYNAMORIO_HOME/clients/bin64/drraw2trace -indir ./raw/ &
  taskPids+=($!)
  sleep 2

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

  traceMap=$(ls $APPHOME/traces/trace/window.0000)
  ################################################################
fi

################################################################
# trace-based or exec-driven simulations
taskPids=()

start=`date +%s`
mkdir -p $APPHOME/simulations/$SCENARIONUM
cp /home/dcuser/scarab/src/PARAMS.sunny_cove $APPHOME/simulations/$SCENARIONUM/PARAMS.in
cd $APPHOME/simulations/$SCENARIONUM
if [ "$TRACE_BASED" == "true" ]; then
  scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace --cbp_trace_r0=$APPHOME/traces/trace/window.0000/${traceMap} --memtrace_modules_log=$APPHOME/traces/raw/ $SCARABPARAMS &> sim.log"
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
