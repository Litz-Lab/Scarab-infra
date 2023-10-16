#!/bin/bash

# code to ignore case restrictions
shopt -s nocasematch

# help function
help()
{
  echo "Usage: ./run_scarab.sh [ -h | --help ]
                [ -o | --outdir ]
                [ -t | --collect_traces]
                [ -b | --build]
                [ -s | --simpoint ]
                [ -m | --mode]"
  echo
  echo "!! Modify 'apps.list' and 'params.new' to specify the apps and Scarab parameters before run !!"
  echo "Options:"
  echo "h     Print this Help."
  echo "o     Output directory (-o <DIR_NAME>) e.g) -o ."
  echo "t     Collect traces. 0: Do not copy collected traces to host, 1: Copy collected traces to host e.g) -t 0 "
  echo "b     Build a docker image. 0: Run a container of existing docker image/cached image without bulding an image from the beginning, 1: with building image from the beginning and overwrite whatever image with the same name. e.g) -b 1"
  echo "s     SimPoint workflow. 0: Not run simpoint workflow, 1: simpoint workflow - instrumentation first (Collect fingerprints, do simpoint clustering, trace/simulate) 2: simpoint workflow - post-processing (trace, collect fingerprints, do simpoint clustering, simulate). e.g) -s 1"
  echo "m     Simulation mode. 0: execution-driven simulation 1: trace-based simulation. e.g) -m 1"
}

SHORT=h:,o:,t:,b:,s:,m:
LONG=help:,outdir:,tracing:,build:,simpoint:,mode:
OPTS=$(getopt -a -n run_scarab.sh --options $SHORT --longoptions $LONG -- "$@")

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
    -t | --tracing) # collect traces
      COLLECTTRACES=$2
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
    -m | --mode) # simulation type for simpoint method
      TRACE_BASED=$2
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

if [ $COLLECTTRACES ] && [ -z "$TRACE_BASED" ]; then
  echo "t should be set only on trace-based simulation mode (-m 1)"
  exit
fi

if [ -z "$OUTDIR" ]; then
  echo "outdir is unset"
  exit
fi

# build docker images and start containers
echo "build docker images and start containers.."
taskPids=()
cat apps.list|while read APPNAME;
do
  eval source setup_apps.sh &
  taskPids+=($!)
  sleep 2
done

echo "wait for all the setups.."
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

# start the workflow
echo "start workflow.."
taskPids=()
cat apps.list|while read APPNAME;
do
  while IFS=, read -r SCENARIONUM SCARABPARAMS; do
    if [ $SIMPOINT ]
    then
      # run scripts for simpoint
      eval docker exec -it --privileged $APP_GROUPNAME /home/dcuser/run_simpoint.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCENARIONUM" "$SCARABPARAMS" "$TRACE_BASED" &
    else
      # run scripts for non-simpoint
      eval docker exec -it --privileged $APP_GROUPNAME /home/dcuser/run_no_simpoint.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCENARIONUM" "$SCARABPARAMS" "$TRACE_BASED" &
    fi
    taskPids+=($!)
    sleep 2
  done < params.new
done

echo "wait for all the workflows..."
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

echo "copy results.."
# copy traces
taskPids=()
cat apps.list|while read APPNAME;
do
  if [ $COLLECTTRACES ]; then
    if [ $SIMPOINT ]; then
      eval docker cp $APP_GROUPNAME:/home/dcuser/simpoint_flow/traces $OUTDIR &
    else
      eval docker cp $APP_GROUPNAME:/home/dcuser/nosimpoint_flow/traces $OUTDIR &
    fi
  fi
  taskPids+=($!)
  # copy Scarab results
  if [ $SIMPOINT ]; then
    eval docker cp $APP_GROUPNAME:/home/dcuser/simpoint_flow/simulations $OUTDIR &
  else
    eval docker cp $APP_GROUPNAME:/home/dcuser/nosimpoint_flow/simulations $OUTDIR &
  fi
  taskPids+=($!)
  sleep 2
done

echo "wait for all copying results..."
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

echo "clean up the containers.."
# remove docker container TODO: an option not to remove the containers immediately (comment out for now)
# solr requires extra cleanup
taskPids=()
cat apps.list|while read APPNAME;
do
case $APPNAME in
  solr)
  eval docker rm web_search_client &
  taskPids+=($!)
  ;;
esac
eval docker rm $APP_GROUPNAME &
taskPids+=($!)
sleep 2
done

echo "wait for all the containers cleaned up..."
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

echo "clean up the volumes.."
# remove docker volume
taskPids=()
cat apps.list|while read APPNAME;
do
eval docker volume rm $APP_GROUPNAME &
taskPids+=($!)
sleep 2
done

echo "wait for all the volumes cleaned up..."
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
