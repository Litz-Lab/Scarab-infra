#!/bin/bash

# code to ignore case restrictions
shopt -s nocasematch

# help function
help()
{
  echo "Usage: ./run_scarab.sh [ -h | --help ]
                [ -a | --appname ]
                [ -p | --parameters ]
                [ -o | --outdir ]
                [ -t | --tracing ]
                [ -b | --build]"
  echo
  echo "Options:"
  echo "h     Print this Help."
  echo "a     Application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress) e.g) -a cassandra"
  echo "p     Scarab parameters. e.g) -p '--frontend memtrace --cbp_trace_r0=<absolute/path/to/trace> --memtrace_modules_log=<absolute/path/to/modules.log> --fetch_off_path_ops 0 --fdip_enable 1'"
  echo "o     Output directory. e.g) -o ."
  echo "t     Collect traces. Run without collecting traces if not given. e.g) -t"
  echo "b     Build a docker image. Run a container of existing docker image without bulding an image if not given. e.g) -b"
}

SHORT=h:,a:,p:,o:,t:,b
LONG=help:,appname:,parameters:,outdir:,tracing:,build
OPTS=$(getopt -a -n run_scarab.sh --options $SHORT --longoptions $LONG -- "$@")

VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

if [ "$VALID_ARGUMENTS" -eq 0 ]; then
  help
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
    -a | --appname) # application name
      APPNAME="$2"
      shift 2
      ;;
    -p | --parameters) # scarab parameters
      SCARABPARAMS="$2"
      shift 2
      ;;
    -o | --outdir) # output directory
      OUTDIR="$2"
      shift 2
      ;;
    -t | --tracing) # collect traces
      COLLECTTRACES=true
      shift
      ;;
    -b | --build) # build a docker image
      BUILD=true
      shift
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

if [ -z "$APPNAME" ]; then
  echo "appname is unset"
  exit
fi

if [ -z "$SCARABPARAMS" ]; then
  echo "parameters is unset"
  exit
fi

if [ -z "$OUTDIR" ]; then
  echo "outdir is unset"
  exit
fi

# build a docker image
if [ $BUILD ]; then
  case $APPNAME in
    cassandra | kafka | tomcat)
      echo "build DaCapo applications"
      docker build . -f ./DaCapo/Dockerfile --no-cache -t $APPNAME:latest
      ;;
    chirper | http)
      echo "build Renaissance applications"
      docker build . -f ./Renaissance/Dockerfile --no-cache -t $APPNAME:latest
      ;;
    drupal7 | mediawiki | wordpress)
      echo "HHVM OSS-performance applications"
      docker build . -f ./OSS/Dockerfile --no-cache -t $APPNAME:latest
      ;;
    *)
      echo "unknown application"
      ;;
  esac
fi

docCommand=""
# collect traces
if [ $COLLECTTRACES ]; then
docCommand+="mkdir /home/memtrace/scarab/traces ; cd /home/memtrace/scarab/traces ; ../src/build/opt/deps/dynamorio/bin64/drrun "
  case $APPNAME in
    cassandra | kafka | tomcat)
      echo "trace DaCapo applications"
    docCommand+="-disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 200M -outdir ./ -- java -jar dacapo-evaluation-git+309e1fa-java8.jar "$APPNAME" -n 10 ; "
    ;;
    chirper | http)
      echo "trace Renaissance applications"
      docCommand+="-disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 200M -outdir ./ -- java -jar renaissance-gpl-0.10.0.jar finagle-"$APPNAME" -r 10 ; "
      ;;
    *)
      echo "unknown application"
      ;;
  esac
fi
docCommand+="bash ../../../scarab/utils/memtrace/run_portabilize_trace.sh ; "

# run Scarab
traceDir=$(cd /home/memtrace/scarab/exp && find ../traces/* -maxdepth 0 -type d)
docCommand+="../src/scarab --frontend memtrace --inst_limit 500000 --fetch_off_path_ops 0 --cbp_trace_r0=$traceDir/trace --memtrace_module_log=$traceDir/bin"

# run a docker container
CID=$(docker run -it $APPNAME:latest /bin/bash -c $docCommand)

# copy Scarab results
docker cp $CID:/home/memtrace/scarab/exp ./exp
