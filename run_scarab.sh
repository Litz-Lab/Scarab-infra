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
  echo "p     Scarab parameters except for --cbp_trace_r0=<absolute/path/to/trace> --memtrace_modules_log=<absolute/path/to/modules.log>. e.g) -p '--frontend memtrace --fetch_off_path_ops 0 --fdip_enable 1 --inst_limit 999900'"
  echo "o     Output directory. e.g) -o ."
  echo "t     Collect traces. Run without collecting traces if not given. e.g) -t"
  echo "b     Build a docker image. Run a container of existing docker image without bulding an image if not given. e.g) -b"
}

SHORT=h:,a:,p:,o:,t,b
LONG=help:,appname:,parameters:,outdir:,tracing:,build
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
    example)
      echo "example"
      docker build . -f ./example/Dockerfile --no-cache -t $APPNAME:latest
      ;;
    *)
      echo "unknown application"
      ;;
  esac
fi

docCommand=""
# collect traces
if [ $COLLECTTRACES ]; then
docCommand+="cd /home/memtrace/traces && /home/memtrace/dynamorio/build/bin64/drrun "
  case $APPNAME in
    cassandra | kafka | tomcat)
      echo "trace DaCapo applications"
      # TODO: Java does not work under DynamoRIO
      docCommand+="-disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0 -t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 101M -outdir ./ -- java -jar ../../dacapo-evaluation-git+309e1fa-java8.jar $APPNAME -n 10 "
    ;;
    chirper | http)
      echo "trace Renaissance applications"
      # TODO: Java does not work under DynamoRIO
      docCommand+="-disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0 -t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 101M -outdir ./ -- java -jar ../../renaissance-gpl-0.10.0.jar finagle-$APPNAME -r 10 "
      ;;
    drupal7 | mediawiki | wordpress)
      echo "trace HHVM OSS applications"
      # TODO: hhvm does not work
      docCommand+="-t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 101M -outdir ./ -- \$HHVM /home/memtrace/oss-performance/perf.php --$APPNAME --hhvm=:$(echo \$HHVM)"
      ;;
    example)
      echo "trace example"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 101M -outdir ./ -- echo hello world"
      ;;
    *)
      echo "unknown application"
      ;;
  esac
docCommand+="&& "
echo $docCommand
fi

# convert traces
docCommand+="cd /home/memtrace/traces && read TRACEDIR < <(bash ../scarab/utils/memtrace/run_portabilize_trace.sh) && "

# run Scarab
docCommand+="cd /home/memtrace/exp && ../scarab/src/scarab --cbp_trace_r0=../traces/\$TRACEDIR/traces --memtrace_modules_log=../traces/\$TRACEDIR/raw "
docCommand+=$SCARABPARAMS
echo $docCommand

# run a docker container - collect traces
docker volume create $APPNAME
docker run -dit --privileged --name $APPNAME -v $APPNAME:/home/memtrace $APPNAME:latest /bin/bash -c $docCommand &
docker logs -f --until=10s $APPNAME &
BACK_PID=$!
echo "run Scarab.."
wait $BACK_PID

# copy traces
docker cp $APPNAME:/home/memtrace/traces $OUTDIR
# copy Scarab results
docker cp $APPNAME:/home/memtrace/exp $OUTDIR

# remove docker container
docker rm $APPNAME
