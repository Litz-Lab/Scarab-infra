#!/bin/bash
set -x #echo on

# code to ignore case restrictions
shopt -s nocasematch

# help function
help()
{
  echo "Usage: ./run.sh [ -h | --help ]
                [ -o | --outdir ]
                [ -b | --build]
                [ -s | --simpoint ]
                [ -t | --collect_traces]
                [ -m | --mode]
                [ -c | --cleanup]"
  echo
  echo "!! Modify 'apps.list' and 'params.new' to specify the apps and Scarab parameters before run !!"
  echo "The entire process of simulating a data center workload is the following."
  echo "1) application setup by building a docker image (each directory represents an application group)"
  echo "2) simpoint workflow to extract the representative execution of each application"
  echo "3) collect traces for trace-based simulation"
  echo "4) run Scarab simulation in different modes"
  echo "To perform the later step, the previous steps must be performed first, meaning all the necessary options should be set at the same time. However, you can only run earlier step(s) by unsetting the later steps for debugging purposes."

  echo "Options:"
  echo "h     Print this Help."
  echo "o     Output existing directory where simpoints/traces/simulation results are copied to (-o <DIR_NAME>). If not given, the results are not copied and only remain in the container. e.g) -o ."
  echo "b     Build a docker image with application setup. 0: Run a container of existing docker image 1: Build cached image and run a container of the cached image, 2: Build a new image from the beginning and overwrite whatever image with the same name. e.g) -b 2"
  echo "s     SimPoint workflow. 0: No simpoint workflow, 1: simpoint workflow - instrumentation first (Collect fingerprints, do simpoint clustering) 2: simpoint workflow - post-processing (trace, collect fingerprints, do simpoint clustering). e.g) -s 1"
  echo "t     Collect traces. 0: Do not collect traces, 1: Collect traces based on the SimPoint workflow (-s). e.g) -t 0 "
  echo "m     Scarab simulation mode. 0: No simulation 1: execution-driven simulation w/o SimPoint 2: trace-based simulation w/o SimPoint (-t should be 1 if no traces exist already in the container). 3: execution-driven simulation w/ SimPoint 4: trace-based simulation w/ SimPoint e.g) -m 4"
  echo "c     Clean up all the containers/volumes after run. 0: No clean up 2: Clean up e.g) -c 1"
}

SHORT=h:,o:,b:,s:,t:,m:
LONG=help:,outdir:,build:,simpoint:,tracing:,mode:
OPTS=$(getopt -a -n run.sh --options $SHORT --longoptions $LONG -- "$@")

VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

if [ "$VALID_ARGUMENTS" -eq 0 ]; then
  help
  exit 0
fi

eval set -- "$OPTS"

# Get the options
while [[ $# -gt 0 ]];
do
  case "$1" in
    -h | --help) # display help
      help
      exit 0
      ;;
    -o | --outdir) # output directory
      OUTDIR="$2"
      shift 2
      ;;
    -b | --build) # build a docker image
      BUILD=$2
      shift 2
      ;;
    -s | --simpoint) # simpoint method
      SIMPOINT=$2
      shift 2
      ;;
    -t | --tracing) # collect traces
      COLLECTTRACES=$2
      shift 2
      ;;
    -m | --mode) # simulation type for simpoint method
      SCARABMODE=$2
      shift 2
      ;;
    -c | --cleanup) # clean up the containers
      CLEANUP=$2
      shift 2
      ;;
    --)
      shift 2
      break
      ;;
    *) # unexpected option
      echo "Unexpected option: $1"
      exit 1
      ;;
  esac
done

# functions
wait_for () {
  # ref: https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument
  # 1: procedure name
  # 2: task list
  local procedure="$1"
  shift
  local taskPids=("$@")
  echo "${taskPids[@]}"
  echo "wait for all $procedure to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    echo "wait for $taskPid $procedure process"
    if wait $taskPid; then
      echo "$procedure process $taskPid success"
    else
      echo "$procedure process $taskPid fail"
      exit
    fi
  done
}

wait_for_non_child () {
  # ref: https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument
  # 1: procedure name
  # 2: task list
  local procedure="$1"
  shift
  local taskPids=("$@")
  echo "${taskPids[@]}"
  echo "wait for all $procedure to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    echo "wait for $taskPid $procedure process"
    while [ -d "/proc/$taskPid" ]; do
      sleep 10 & wait $!
    done
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

# build docker images and start containers
echo "build docker images and start containers.."
taskPids=()
start=`date +%s`
while read APPNAME ;do
  source setup_apps.sh

  if [ $BUILD ]; then
    source build_apps.sh
  fi

  if [ $SIMPOINT ] || [ $COLLECTTRACES ]; then
    # run simpoint/trace
    echo "run simpoint/trace.."

    docker exec --privileged $APP_GROUPNAME /home/dcuser/run_simpoint_trace.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SIMPOINT" "$COLLECTTRACES" &
    sleep 2
    while read -r line ;do
      IFS=" " read PID CMD <<< $line
      if [ "$CMD" == "/bin/bash /home/dcuser/run_simpoint_trace.sh $APPNAME $APP_GROUPNAME $BINCMD $SIMPOINT $COLLECTTRACES" ]; then
        taskPids+=($PID)
      fi
    done < <(docker top $APP_GROUPNAME -eo pid,cmd)
  fi
done < apps.list

wait_for_non_child "simpoint/tracing" "${taskPids[@]}"
end=`date +%s`
report_time "post-processing" "$start" "$end"

if [ $SCARABMODE ]; then
  # run Scarab simulation
  echo "run Scarab simulation.."
  taskPids=()
  start=`date +%s`

  while read APPNAME; do
    source setup_apps.sh
    while IFS=, read -r SCENARIONUM SCARABPARAMS; do
      docker exec --privileged $APP_GROUPNAME /home/dcuser/run_scarab.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCENARIONUM" "$SCARABPARAMS" "$SCARABMODE" &
      sleep 2
      while read -r line; do
        IFS=" " read PID CMD <<< $line
        if [ "$CMD" == "/bin/bash /home/dcuser/run_scarab.sh $APPNAME $APP_GROUPNAME $BINCMD $SCENARIONUM $SCARABPARAMS $SCARABMODE" ]; then
          taskPids+=($PID)
        fi
      done < <(docker top $APP_GROUPNAME -eo pid,cmd)
    done < params.new
  done < apps.list

  wait_for_non_child "Scarab-simulation" "${taskPids[@]}"
  end=`date +%s`
  report_time "Scarab-simulation" "$start" "$end"
fi

if [ $OUTDIR ]; then
  echo "copy results.."
  taskPids=()
  start=`date +%s`
  while read APPNAME ; do
    source setup_apps.sh
    if [ $SIMPOINT ]; then
      copyCmd="docker cp $APP_GROUPNAME:/home/dcuser/simpoint_flow $OUTDIR"
      eval $copyCmd &
    else
      copyCmd="docker cp $APP_GROUPNAME:/home/dcuser/nonsimpoint_flow $OUTDIR"
      eval $copyCmd &
    fi
    taskPids+=($!)
    sleep 2
  done < apps.list

  wait_for "copying-results" "${taskPids[@]}"
  end=`date +%s`
  report_time "copying-results" "$start" "$end"
fi

if [ $CLEANUP ]; then
  echo "clean up the containers.."
  # solr requires extra cleanup
  taskPids=()
  start=`date +%s`
  while read APPNAME ;do
    source setup_apps.sh
    case $APPNAME in
      solr)
        rmCmd="docker rm web_search_client"
        eval $rmCmd &
        taskPids+=($!)
        sleep 2
        ;;
    esac
    docker stop $APP_GROUPNAME
    rmCmd="docker rm $APP_GROUPNAME"
    eval $rmCmd &
    taskPids+=($!)
    sleep 2
  done < apps.list

  wait_for "container-cleanup" "${taskPids[@]}"
  end=`date +%s`
  report_time "container-cleanup" "$start" "$end"

  echo "clean up the volumes.."
  # remove docker volume
  taskPids=()
  start=`date +%s`
  while read APPNAME ; do
    source setup_apps.sh
    rmCmd="docker volume rm $APP_GROUPNAME"
    eval $rmCmd &
    taskPids+=($!)
    sleep 2
  done < apps.list

  wait_for "volume-cleanup" "${taskPids[@]}"
  end=`date +%s`
  report_time "volume-cleanup" "$start" "$end"
fi
