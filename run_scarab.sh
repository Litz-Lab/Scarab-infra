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
                [ -t | --collect_traces]
                [ -b | --build]"
  echo
  echo "Options:"
  echo "h     Print this Help."
  echo "a     Application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress, compression, hashing, mem, proto, cold_swissmap, hot_swissmap, empirical_driver) e.g) -a cassandra"
  echo "p     Scarab parameters. e.g) -p '--frontend memtrace --fetch_off_path_ops 1 --fdip_enable 1 --inst_limit 999900 --uop_cache_enable 0'"
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
      docker build . -f ./DaCapo/Dockerfile --no-cache -t $APPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    chirper | http)
      echo "build Renaissance applications"
      docker build . -f ./Renaissance/Dockerfile --no-cache -t $APPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    drupal7 | mediawiki | wordpress)
      echo "HHVM OSS-performance applications"
      docker build . -f ./OSS/Dockerfile --no-cache -t $APPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    compression | hashing | mem | proto | cold_swissmap | hot_swissmap | empirical_driver)
      echo "fleetbench applications"
      docker build . -f ./Fleetbench/Dockerfile --no-cache -t $APPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    example)
      echo "example"
      docker build . -f ./example/Dockerfile --no-cache -t $APPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    *)
      echo "unknown application"
      ;;
  esac
fi

# set BINPATH
case $APPNAME in
  compression)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/compression/compression_benchmark"
    ;;
  hashing)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/hashing/hashing_benchmark"
    ;;
  mem)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/libc/mem_benchmark"
    ;;
  proto)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/proto/proto_benchmark"
    ;;
  cold_swissmap | hot_swissmap)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/$APPNAME"
    BINPATH+="_benchmark"
    ;;
  empirical_driver)
    BINPATH="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/tcmalloc/empirical_driver"
    ;;
esac

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
    compression)
      echo "trace fleetbench compression benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
      ;;
    hashing)
      echo "trace fleetbench hashing benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
      ;;
    mem)
      echo "trace fleetbench libc mem benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
      ;;
    proto)
      echo "trace fleetbench proto benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
      ;;
    cold_swissmap | hot_swissmap)
      echo "trace fleetbench swissmap benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
      ;;
    empirical_driver)
      echo "trace fleetbench tcmalloc empirical_driver benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINPATH "
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
# convert traces
docCommand+="cd /home/memtrace/traces && read TRACEDIR < <(bash ../scarab_hlitz/utils/memtrace/run_portabilize_trace.sh) && "
echo $docCommand
fi

# run Scarab
docCommand+="cd /home/memtrace/exp && python3 /home/memtrace/scarab_hlitz/bin/scarab_launch.py --program '$BINPATH' --param '/home/memtrace/scarab_hlitz/src/PARAMS.sunny_cove' --scarab_args '$SCARABPARAMS'"
echo $docCommand

# run a docker container
docker volume create $APPNAME
echo "run Scarab.."
docker run -it --privileged --name $APPNAME -v $APPNAME:/home/memtrace $APPNAME:latest /bin/bash -c "$docCommand"

echo "copy results.."
# copy traces
if [ $COLLECTTRACES ]; then
  docker cp $APPNAME:/home/memtrace/traces $OUTDIR
fi
# copy Scarab results
docker cp $APPNAME:/home/memtrace/exp $OUTDIR

# remove docker container
docker rm $APPNAME

# remove docker volume
docker volume rm $APPNAME
