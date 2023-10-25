#!/bin/bash

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SEGSIZE=100000000
SIMPOINT="$4"
COLLECTTRACES="$5"

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

if [ "$SIMPOINT" == "1" ]; then
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
  wc_result=($(wc $APPHOME/fingerprint/bbfp))
  lines=${wc_result[0]}
  # round to nearest int
  maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
  echo "fingerprint size: $lines, maxk: $maxK"
  spCmd="/home/dcuser/simpoint -maxK $maxK -fixedLength off -numInitSeeds 1000 -loadFVFile $APPHOME/fingerprint/bbfp -saveSimpoints $APPHOME/simpoints/opt.p -saveSimpointWeights $APPHOME/simpoints/opt.w -saveLabels $APPHOME/simpoints/opt.l &> $APPHOME/simpoints/simp.opt.log"
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