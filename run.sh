#!/bin/bash
#set -x #echo on

# code to ignore case restrictions
shopt -s nocasematch

# help function
help()
{
  echo "Usage: ./run.sh [ -h | --help ]
                [ -o | --outdir ]
                [ -b | --build]
                [ -t | --trace]
                [ -s | --scarab ]
                [ -e | --experiment ]
                [ -p | --plot ]
                [ -c | --cleanup]"
  echo
  echo "!! Modify 'apps.list' and '<experiment_name>.json' to specify the apps to build and Scarab parameters before run !!"
  echo "The entire process of simulating a data center workload is the following."
  echo "1) application setup by building a docker image (each directory represents an application group)"
  echo "2) collect traces with different simpoint workflows for trace-based simulation"
  echo "3) run Scarab simulation in different modes"
  echo "To perform the later step, the previous steps must be performed first, meaning all the necessary options should be set at the same time. However, you can only run earlier step(s) by unsetting the later steps for debugging purposes."

  echo "Options:"
  echo "h     Print this Help."
  echo "o     Absolute path to the directory for scarab repo, pin, traces, simpoints, and simulation results. scarab and pin will be installed if they don't exist in the given path. The directory will be mounted as home directory of a container e.g) -o /soe/user/testbench_container_home"
  echo "b     Build a docker image with application setup. 0: Run a container of existing docker image 1: Build cached image and run a container of the cached image, 2: Build a new image from the beginning and overwrite whatever image with the same name. e.g) -b 2"
  echo "t     Collect traces with different SimPoint workflows. 0: Do not collect traces, 1: Only collect traces without simpoint clustering, 2: Collect traces based on SimPoint workflow - post-processing (trace, collect fingerprints, do simpoint clustering). e.g) -t 2"
  echo "s     Scarab simulation mode. 0: No simulation 1: execution-driven simulation w/o SimPoint 2: trace-based simulation w/o SimPoint (-t should be 1 if no traces exist already in the container). 3: execution-driven simulation w/ SimPoint 4: trace-based simulation w/ SimPoint. 5: trace-based simulation w/o SimPoint with pt e.g) -s 4"
  echo "e     Experiment name. e.g.) -e exp2"
  echo "p     Plot figures by using <exp>.json. e.g.) -p 1"
  echo "c     Clean up all the containers/volumes after run. 0: No clean up 2: Clean up e.g) -c 1"
}

SHORT=h:,o:,b:,t:,s:,e:,p:,c:
LONG=help:,outdir:,build:,trace:,scarab:,experiment:,plot:,cleanup:
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
    -t | --trace) # collect traces with simpoint workflows
      SIMPOINT=$2
      shift 2
      ;;
    -s | --scarab) # scarab simulation mode
      SCARABMODE=$2
      shift 2
      ;;
    -e | --experiment) # experiment name
      EXPERIMENT=$2
      shift 2
      ;;
    -p | --plot) # plot figures
      PLOT=$2
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

if [ ! -n "$OUTDIR" ]; then
  echo "The output directory path should be provided. (e.g. -o /soe/user/testbench_container_home)"
  exit 1
fi

mkdir -p $OUTDIR

source utilities.sh

# build docker images and start containers
echo "build docker images and start containers.."
taskPids=()
start=`date +%s`
while read APPNAME ;do
  source setup_apps.sh

  if [ $BUILD ]; then
    source build_apps.sh
  fi

  if [ $SIMPOINT ]; then
    if [ "$APPNAME" == "allbench" ]; then
      echo "allbench is only for trace-based simulations with the traces from UCSC NFS"
      exit 1
    fi
    # run simpoint/trace
    echo "run simpoint/trace.."

    # tokenize multiple environment variables
    ENVVARS=""
    echo $ENVVARS
    for token in $ENVVAR;
    do
       ENVVARS+=" -e ";
       ENVVARS+=$token;
    done

    # update the script
    docker cp ./run_simpoint_trace.sh $APP_GROUPNAME\_$USER:/usr/local/bin
    docker exec $ENVVARS --user $USER --workdir /home/$USER --privileged $APP_GROUPNAME\_$USER run_simpoint_trace.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SIMPOINT" "$DRIO_ARGS" &
    sleep 2
    while read -r line ;do
      IFS=" " read PID CMD <<< $line
      if [ "$CMD" == "/bin/bash /usr/local/bin/run_simpoint_trace.sh $APPNAME $APP_GROUPNAME $BINCMD $SIMPOINT $DRIO_ARGS" ]; then
        taskPids+=($PID)
      fi
    done < <(docker top $APP_GROUPNAME\_$USER -eo pid,cmd)
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
    # update the script
    if [ "$APP_GROUPNAME" == "cse220" ]; then
      docker cp ./$APP_GROUPNAME/run_exp_using_descriptor.py $APP_GROUPNAME\_$USER:/usr/local/bin
      docker cp ./$APP_GROUPNAME/run_cse220.sh $APP_GROUPNAME\_$USER:/usr/local/bin
    else
      docker cp ./run_exp_using_descriptor.py $APP_GROUPNAME\_$USER:/usr/local/bin
    fi
    if [ "$APP_GROUPNAME" == "allbench_traces" ]; then
      cp ${EXPERIMENT}.json $OUTDIR
      docker exec --user $USER --workdir /home/$USER --privileged $APP_GROUPNAME\_$USER python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -m $SCARABMODE &
      while read -r line; do
        IFS=" " read PID CMD <<< $line
        if [ "$CMD" == "python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -m $SCARABMODE" ]; then
          taskPids+=($PID)
        fi
      done < <(docker top $APP_GROUPNAME\_$USER -eo pid,cmd)
    elif [ "$APP_GROUPNAME" == "isca2024_udp" ] || [ "$APP_GROUPNAME" == "docker_traces" ] || [ "$APP_GROUPNAME" == "cse220" ]; then
      cp ${APP_GROUPNAME}/${EXPERIMENT}.json $OUTDIR
      docker exec --user $USER --workdir /home/$USER --privileged $APP_GROUPNAME\_$USER python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -m $SCARABMODE &
      while read -r line; do
        IFS=" " read PID CMD <<< $line
        if [ "$CMD" == "python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -m $SCARABMODE" ]; then
          taskPids+=($PID)
        fi
      done < <(docker top $APP_GROUPNAME\_$USER -eo pid,cmd)
    else
      cp ${EXPERIMENT}.json $OUTDIR
      docker exec --user $USER --workdir /home/$USER --privileged $APP_GROUPNAME\_$USER python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -c $BINCMD -m $SCARABMODE &
      while read -r line; do
        IFS=" " read PID CMD <<< $line
        if [ "$CMD" == "python3 /usr/local/bin/run_exp_using_descriptor.py -d $EXPERIMENT.json -a $APPNAME -g $APP_GROUPNAME -c $BINCMD -m $SCARABMODE" ]; then
          taskPids+=($PID)
        fi
      done < <(docker top $APP_GROUPNAME\_$USER -eo pid,cmd)
    fi
  done < apps.list

  wait_for_non_child "Scarab-simulation" "${taskPids[@]}"
  end=`date +%s`
  report_time "Scarab-simulation" "$start" "$end"
fi

if [ $PLOT ]; then
  # plot figures by using json exp descriptor
  echo "plot figures.."
  taskPids=()
  start=`date +%s`

  while read APPNAME; do
    source setup_apps.sh
    # update the script
    if [ "$APP_GROUPNAME" == "cse220" ]; then
      docker cp ./$APP_GROUPNAME/plot/. $APP_GROUPNAME\_$USER:/usr/local/bin/plot
    else
      docker cp ./plot/. $APP_GROUPNAME\_$USER:/usr/local/bin/plot
    fi
    cp ${APP_GROUPNAME}/${EXPERIMENT}.json $OUTDIR
    docker exec --user $USER --env USER=$USER --env EXPERIMENT=$EXPERIMENT --workdir /home/$USER --privileged $APP_GROUPNAME\_$USER /bin/bash /usr/local/bin/plot/plot_figures.sh
  done < apps.list
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
    docker stop $APP_GROUPNAME\_$USER
    rmCmd="docker rm $APP_GROUPNAME\_$USER"
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
