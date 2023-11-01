#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SEGSIZE=100000000
SIMPOINT="$4"
COLLECTTRACES="$5"

# functions
wait_for () {
  # ref: https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument
  # 1: procedure name
  # 2: task list
  local procedure="$1"
  shift
  local taskPids=("$@")
  echo "wait for all $procedure to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "$procedure process $taskPid success"
    else
      echo "$procedure process $taskPid fail"
      # # ref: https://serverfault.com/questions/479460/find-command-from-pid
      # cat /proc/${taskPid}/cmdline | xargs -0 echo
      # exit
    fi
  done
}

report_time () {
  # 1: procedure name
  # 2: start
  # 3: end
  local procedure="$1"
  local start="$2"
  local end="$3"
  local runtime=$((end-start))
  local hours=$((runtime / 3600));
  local minutes=$(( (runtime % 3600) / 60 ));
  local seconds=$(( (runtime % 3600) % 60 ));
  echo "$procedure Runtime: $hours:$minutes:$seconds (hh:mm:ss)"
}

run_simpoint () {
  local lines=($(wc -l $APPHOME/fingerprint/bbfp))
  # round to nearest int
  local maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
  echo "fingerprint size: $lines, maxk: $maxK"
  local spCmd="/home/dcuser/simpoint -maxK $maxK -fixedLength off -numInitSeeds 1000 -loadFVFile $APPHOME/fingerprint/bbfp -saveSimpoints $APPHOME/simpoints/opt.p -saveSimpointWeights $APPHOME/simpoints/opt.w -saveLabels $APPHOME/simpoints/opt.l &> $APPHOME/simpoints/simp.opt.log"
  echo "cluster fingerprint..."
  echo "command: ${spCmd}"
  start=`date +%s`
  eval $spCmd
  end=`date +%s`
  report_time "clustering" "$start" "$end"
}

# Get command to run for Spe17
if [ "$APP_GROUPNAME" == "spec2017" ] && [ "$APPNAME" != "clang" ]; then
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

if [ "$SIMPOINT" == "2" ]; then
  # dir for all relevant data: fingerprint, traces, log, sim stats...
  mkdir -p /home/dcuser/simpoint_flow/$APPNAME
  cd /home/dcuser/simpoint_flow/$APPNAME
  mkdir -p fingerprint simpoints traces
  APPHOME=/home/dcuser/simpoint_flow/$APPNAME


  ################################################################

  # 1. trace the whole application
  # 2. drraw2trace
  # 3. post-process the trace in parallel
  # 4. aggregate the fingerprint
  # 5. clustering

  taskPids=()
  start=`date +%s`

  mkdir -p $APPHOME/traces/whole
  cd $APPHOME/traces/whole
  traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces/whole -offline -- ${BINCMD}"
  echo "tracing whole app..."
  echo "command: ${traceCmd}"
  # if [ "$APP_GROUPNAME" == "spec2017" ]; then
  #   # have to go to that dir for the spec app cmd to work
  #   ogo $APPNAME run
  #   cd run_base_train*
  # fi
  eval $traceCmd &
  taskPids+=($!)

  wait_for "whole app tracing" "${taskPids[@]}"
  end=`date +%s`
  report_time "whole app tracing" "$start" "$end"

  taskPids=()
  start=`date +%s`

  cd $APPHOME/traces/whole
  for dr in dr*;
  do
    cd $dr
    mkdir -p bin
    cp raw/modules.log bin/modules.log
    cp raw/modules.log raw/modules.log.bak
    echo "dcuser" | sudo -S python2 /home/dcuser/scarab/utils/memtrace/portabilize_trace.py .
    cp bin/modules.log raw/modules.log
    $DYNAMORIO_HOME/clients/bin64/drraw2trace -jobs 40 -indir ./raw/ -chunk_instr_count $SEGSIZE &
    taskPids+=($!)
  done

  wait_for "whole app raw2trace" "${taskPids[@]}"
  end=`date +%s`
  report_time "whole app raw2trace" "$start" "$end"

  numChunk=$(unzip -l ./trace/dr*.zip | grep "chunk." | wc -l)
  echo "total number of segments/chunks: $numChunk"

  # post-processing
  taskPids=()
  start=`date +%s`

  cd $APPHOME/fingerprint
  mkdir -p pieces

  wholeTrace=$(ls $APPHOME/traces/whole/trace/dr*.zip)
  for chunkID in $(seq 0 $(( $numChunk-1 )))
  do
    mkdir -p $chunkID
    # do not care about the params file
    cd $chunkID
    scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace \
              --cbp_trace_r0=$wholeTrace \
              --memtrace_modules_log=$APPHOME/traces/whole/raw/ \
              --mode=trace_bbv_distributed \
              --chunk_instr_count=$SEGSIZE \
              --memtrace_roi_begin=$(( $chunkID * $SEGSIZE + 1 )) \
              --memtrace_roi_end=$(( $chunkID * $SEGSIZE + $SEGSIZE )) \
              --trace_bbv_output=$APPHOME/fingerprint/pieces/chunk.$chunkID \
              &> sim.log"
    echo "processing chunkID ${chunkID}..."
    echo "command: ${scarabCmd}"
    eval $scarabCmd &
    taskPids+=($!)
    cd -
  done

  wait_for "post-processing" "${taskPids[@]}"
  end=`date +%s`
  report_time "post-processing" "$start" "$end"

  # aggregate the fingerprint pieces
  cd /home/dcuser
  python3 ./gather_fp_pieces.py $APPHOME/fingerprint/pieces $numChunk
  cp $APPHOME/fingerprint/pieces/bbfp $APPHOME/fingerprint/bbfp

  # clustering
  run_simpoint

elif [ "$SIMPOINT" == "1" ]; then
  # dir for all relevant data: fingerprint, traces, log, sim stats...
  mkdir -p /home/dcuser/simpoint_flow/$APPNAME
  cd /home/dcuser/simpoint_flow/$APPNAME
  mkdir -p fingerprint simpoints traces
  APPHOME=/home/dcuser/simpoint_flow/$APPNAME


  ################################################################

  # collect fingerprint
  # TODO: add parameter: size and warm-up
  cd $APPHOME/fingerprint
  fpCmd="$DYNAMORIO_HOME/bin64/drrun -opt_cleancall 2 -c /home/dcuser/libfpg.so -segment_size $SEGSIZE -- $BINCMD"
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
  run_simpoint

  ################################################################
  # read in simpoint
  # ref: https://stackoverflow.com/q/56005842
  # map of cluster - segment
  declare -A clusterMap
  while IFS=" " read -r segID clusterID; do
    clusterMap[$clusterID]=$segID 
  done < $APPHOME/simpoints/opt.p

  ################################################################
  # collect traces

  if [ "$COLLECTTRACES" == "1" ]; then
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
      echo "dcuser" | sudo -S python2 /home/dcuser/scarab/utils/memtrace/portabilize_trace.py .
      cp bin/modules.log raw/modules.log
      $DYNAMORIO_HOME/clients/bin64/drraw2trace -indir ./raw/ &
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
  fi
else # non-simpoint
  # dir for all relevant data: traces, log, sim stats...
  mkdir -p /home/dcuser/nonsimpoint_flow/$APPNAME
  cd /home/dcuser/nonsimpoint_flow/$APPNAME
  mkdir -p traces
  APPHOME=/home/dcuser/nonsimpoint_flow/$APPNAME

  ################################################################
  # collect traces

  if [ "$COLLECTTRACES" == "1" ]; then
    # tracing, raw2trace
    taskPids=()
    start=`date +%s`
    mkdir -p $APPHOME/traces
    cd $APPHOME/traces
    start_inst=$(( 20 * $SEGSIZE ))
    SEGSIZE=$(( 50 * $SEGSIZE ))

    case $APPNAME in
      cassandra | kafka | tomcat)
        # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
        traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -exit_after_tracing $SEGSIZE -- ${BINCMD}"
        ;;
      chirper | http)
        # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
        traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -exit_after_tracing $SEGSIZE -- ${BINCMD}"
        ;;
      solr)
        # TODO: Java does not work under DynamoRIO : tried -disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0
        # https://github.com/DynamoRIO/dynamorio/commits/i3733-jvm-bug-fixes does not work: "DynamoRIO Cache Simulator Tracer interval crash at PC 0x00007fe16d8e8fdb. Please report this at https://dynamorio.org/issues"
        # Scarab does not work either: "setarch: failed to set personality to x86_64: Operation not permitted"
        # Solr uses many threads and seems to run too long on simpoint's fingerprint collection
        traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -exit_after_tracing $SEGSIZE -- ${BINCMD}"
        ;;
      *)
        traceCmd="$DYNAMORIO_HOME/bin64/drrun -t drcachesim -jobs 40 -outdir $APPHOME/traces -offline -trace_after_instrs $start_inst -exit_after_tracing $SEGSIZE -- ${BINCMD}"
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
    echo "dcuser" | sudo -S python2 /home/dcuser/scarab/utils/memtrace/portabilize_trace.py .
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

  ################################################################
  fi
fi
###############################################################