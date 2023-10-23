#!/bin/bash

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

# build docker images and start containers
echo "build docker images and start containers.."
taskPids=()
cat apps.list|while read APPNAME;
do
  source setup_apps.sh
  source build_apps.sh

  if [ $SIMPOINT ] || [ $COLLECTTRACES ]; then
    # run simpoint/trace
    echo "run simpoint/trace.."

    eval docker exec -i --privileged $APP_GROUPNAME /home/dcuser/run_simpoint_trace.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SIMPOINT" "$COLLECTTRACES" &
    taskPids+=($!)
    sleep 2
  fi
done

echo "wait for all the simpoint/tracing..."
for taskPid in ${taskPids[@]}; do
  if wait $taskPid; then
    echo "simpoint/trace process $taskPid success"
  else
    echo "simpoint/trace process $taskPid fail"
    exit
  fi
done

if [ $SCARABMODE ]; then
  # run Scarab simulation
  echo "run Scarab simulation.."
  taskPids=()

  cat apps.list|while read APPNAME;
  do
    source setup_apps.sh
    while IFS=, read -r SCENARIONUM SCARABPARAMS; do
      eval docker exec -i --privileged $APP_GROUPNAME /home/dcuser/run_scarab.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCENARIONUM" "$SCARABPARAMS" "$SCARABMODE" &
      taskPids+=($!)
      sleep 2
    done < params.new
  done

  echo "wait for all the Scarab simulations..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "simulation process $taskPid success"
    else
      echo "simulation process $taskPid fail"
      exit
    fi
  done
fi

if [ $OUTDIR ]; then
  echo "copy results.."
  taskPids=()
  cat apps.list|while read APPNAME;
  do
    source setup_apps.sh
    if [ $SIMPOINT ]; then
      eval docker cp $APP_GROUPNAME:/home/dcuser/simpoint_flow $OUTDIR &
    else
      eval docker cp $APP_GROUPNAME:/home/dcuser/nonsimpoint_flow $OUTDIR &
    fi
    taskPids+=($!)
    sleep 2
  done

  echo "wait for all copying results..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "copying process $taskPid success"
    else
      echo "copying process $taskPid fail"
      exit
    fi
  done
fi

if [ $CLEANUP ]; then
  echo "clean up the containers.."
  # solr requires extra cleanup
  taskPids=()
  cat apps.list|while read APPNAME;
  do
    source setup_apps.sh
    case $APPNAME in
      solr)
        eval docker rm web_search_client &
        taskPids+=($!)
        ;;
    esac
    docker stop $APP_GROUPNAME
    eval docker rm $APP_GROUPNAME &
    taskPids+=($!)
    sleep 2
  done

  echo "wait for all the containers cleaned up..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "container cleaning up process $taskPid success"
    else
      echo "container cleaning up process $taskPid fail"
      exit
    fi
  done

  echo "clean up the volumes.."
  # remove docker volume
  taskPids=()
  cat apps.list|while read APPNAME;
  do
    source setup_apps.sh
    eval docker volume rm $APP_GROUPNAME &
    taskPids+=($!)
    sleep 2
  done

  echo "wait for all the volumes cleaned up..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "volume cleaning up process $taskPid success"
    else
      echo "volume cleaning up process $taskPid fail"
      exit
    fi
  done
fi
