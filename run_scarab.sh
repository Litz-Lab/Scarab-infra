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
                [ -b | --build]
                [ -sp | --simpoint ]"
  echo
  echo "Options:"
  echo "h     Print this Help."
  echo "a     Application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress, compression, hashing, mem, proto, cold_swissmap, hot_swissmap, empirical_driver, verilator) e.g) -a cassandra"
  echo "p     Scarab parameters. e.g) -p '--frontend memtrace --fetch_off_path_ops 1 --fdip_enable 1 --inst_limit 999900 --uop_cache_enable 0'"
  echo "o     Output directory. e.g) -o ."
  echo "t     Collect traces. Run without collecting traces if not given. e.g) -t"
  echo "b     Build a docker image. Run a container of existing docker image without bulding an image if not given. e.g) -b"
  echo "sp    Run SimPoint workflow. Collect fingerprint, trace, simulate, and report. e.g) -sp"
}

SHORT=h:,a:,p:,o:,t,b,sp
LONG=help:,appname:,parameters:,outdir:,tracing:,build:,simpoint
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
    -sp | --simpoint) # simpoint method
      SIMPOINT=true
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

if [ $COLLECTTRACES ] && [ -z "$SCARABPARAMS" ]; then
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
      APP_GROUPNAME="dacapo"
      docker build . -f ./DaCapo/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    chirper | http)
      echo "build Renaissance applications"
      APP_GROUPNAME="renaissance"
      docker build . -f ./Renaissance/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    drupal7 | mediawiki | wordpress)
      echo "HHVM OSS-performance applications"
      APP_GROUPNAME="oss"
      docker build . -f ./OSS/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    compression | hashing | mem | proto | cold_swissmap | hot_swissmap | empirical_driver)
      echo "fleetbench applications"
      APP_GROUPNAME="fleetbench"
      docker build . -f ./Fleetbench/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    verilator)
      echo "verilator"
      APP_GROUPNAME="verilator"
      docker build . -f ./Verilator/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    example)
      echo "example"
      APP_GROUPNAME="example"
      docker build . -f ./example/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    # TODO: add all SPEC names
    502.gcc_r)
      echo "spec2017"
      APP_GROUPNAME="spec2017"
      DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./SPEC2017/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat /home/mxu61_bak/.ssh/id_rsa)"
      ;;
    *)
      APP_GROUPNAME="unknown"
      echo "unknown application"
      ;;
  esac
fi

# set BINCMD
case $APPNAME in
  compression)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/compression/compression_benchmark"
    ;;
  hashing)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/hashing/hashing_benchmark"
    ;;
  mem)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/libc/mem_benchmark"
    ;;
  proto)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/proto/proto_benchmark"
    ;;
  cold_swissmap | hot_swissmap)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/$APPNAME"
    BINCMD+="_benchmark"
    ;;
  empirical_driver)
    BINCMD="/home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/tcmalloc/empirical_driver"
    ;;
  verilator)
    BINCMD="/home/memtrace/rocket-chip/emulator/emulator-freechips.rocketchip.system-freechips.rocketchip.system.DefaultConfig /home/memtrace/rocket-chip/riscv/riscv64-unknown-elf/share/riscv-tests/benchmarks/dhrystone.riscv"
    ;;
esac

# create volume for the app group
docker volume create $APP_GROUPNAME

# start container
docker run -dit --privileged --name $APP_GROUPNAME -v $APP_GROUPNAME:/home/memtrace $APP_GROUPNAME:latest /bin/bash
# mount and install spec benchmark
if [ $BUILD ] && [ "$APP_GROUPNAME" == "spec2017" ]; then
  # TODO: make it inside docker file?
  # no detach, wait for it to terminate
  echo "installing spec 2017..."
  docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "cd /home/memtrace && mkdir cpu2017_install && echo \"memtrace\" | sudo -S mount -t iso9660 -o ro,exec,loop cpu2017-1_0_5.iso ./cpu2017_install"
  docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "cd /home/memtrace && mkdir cpu2017 && cd cpu2017_install && echo \"yes\" | ./install.sh -d /home/memtrace/cpu2017"
  docker cp ./SPEC2017/memtrace.cfg $APP_GROUPNAME:/home/memtrace/cpu2017/config/memtrace.cfg
fi

# collect traces
if [ $COLLECTTRACES ]; then
docCommand=""
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
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    hashing)
      echo "trace fleetbench hashing benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    mem)
      echo "trace fleetbench libc mem benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    proto)
      echo "trace fleetbench proto benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    cold_swissmap | hot_swissmap)
      echo "trace fleetbench swissmap benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    empirical_driver)
      echo "trace fleetbench tcmalloc empirical_driver benchmark"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    verilator)
      echo "trace verilator"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
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
docCommand+="cd /home/memtrace/traces && read TRACEDIR < <(bash ../scarab/utils/memtrace/run_portabilize_trace.sh) && "
echo $docCommand

# run Scarab
docCommand+="cd /home/memtrace/exp && python3 /home/memtrace/scarab/bin/scarab_launch.py --program '$BINCMD' --param '/home/memtrace/scarab/src/PARAMS.sunny_cove' --scarab_args '$SCARABPARAMS'"
echo $docCommand

# run a docker container
echo "run Scarab.."
docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "$docCommand"
fi

# the simpoint workflow
if [ $SIMPOINT ]; then
  # run scripts for simpoint
  # docker exec -dit --privileged $APP_GROUPNAME /home/memtrace/run_simpoint.sh $APP_GROUPNAME &
  docker exec -it --privileged $APP_GROUPNAME /home/memtrace/run_simpoint.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCARABPARAMS"
fi

echo "copy results.."
# copy traces
if [ $COLLECTTRACES ]; then
  docker cp $APP_GROUPNAME:/home/memtrace/traces $OUTDIR
fi
# copy Scarab results
docker cp $APP_GROUPNAME:/home/memtrace/exp $OUTDIR

# remove docker container
# TODO: may not want to remove immediately -- in case of running multiple apps using same image/container
docker rm $APP_GROUPNAME

# remove docker volume
# TODO: may not want to remove immediately -- in case of running multiple apps using same image/container
docker volume rm $APP_GROUPNAME
