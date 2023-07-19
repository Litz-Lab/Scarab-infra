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
                [ -s | --simpoint ]
                [ -x | --trace_based ]"
  echo
  echo "Options:"
  echo "h     Print this Help."
  echo "a     Application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress, compression, hashing, mem, proto, cold_swissmap, hot_swissmap, empirical_driver, verilator, dss, httpd) e.g) -a cassandra"
  echo "p     Scarab parameters. e.g) -p '--frontend memtrace --fetch_off_path_ops 1 --fdip_enable 1 --inst_limit 999900 --uop_cache_enable 0'"
  echo "o     Output directory. e.g) -o ."
  echo "t     Collect traces. Run without collecting traces if not given. e.g) -t"
  echo "b     Build a docker image. Run a container of existing docker image without bulding an image if not given. e.g) -b"
  echo "s     Run SimPoint workflow. Collect fingerprint, trace, simulate, and report. e.g) -s"
  echo "x     Run trace-based simulations for the SimPoint workflow. Otherwise, run executable-driven simulations. e.g) -x"
}

SHORT=h:,a:,p:,o:,t,b,s,x
LONG=help:,appname:,parameters:,outdir:,tracing:,build:,simpoint:,trace_based
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
    -s | --simpoint) # simpoint method
      SIMPOINT=true
      shift
      ;;
    -x | --trace_based) # simulation type for simpoint method
      TRACE_BASED=true
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
    dss)
      echo "dss"
      APP_GROUPNAME="dss"
      docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    httpd)
      echo "httpd"
      APP_GROUPNAME="httpd"
      docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    example)
      echo "example"
      APP_GROUPNAME="example"
      docker build . -f ./example/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    solr)
      echo "solr"
      APP_GROUPNAME="solr"
      docker build . -f ./solr/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
      ;;
    # TODO: add all SPEC names
    508.namd_r | 519.lbm_r | 520.omnetpp_r | 527.cam4_r | 548.exchange2_r | 549.fotonik3d_r)
      echo "spec2017"
      APP_GROUPNAME="spec2017"
      DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./SPEC2017/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
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
    BINCMD="/home/memtrace/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfigN8 +cycle-count /home/memtrace/rocket-chip/emulator/dhrystone-head.riscv"
    ;;
  dss)
    BINCMD="DarwinStreamingServer -d"
    ;;
  httpd)
    BINCMD="/usr/local/apache2/bin/httpd -C 'ServerName 172.17.0.2:80' -X"
    ;;
  solr)
    BINCMD="java -server -Xms14g -Xmx14g -XX:+UseG1GC -XX:+PerfDisableSharedMem -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=250 -XX:+UseLargePages -XX:+AlwaysPreTouch -XX:+ExplicitGCInvokesConcurrent -Xlog:gc\*:file=/usr/src/solr-9.1.1/server/logs/solr_gc.log:time\,uptime:filecount=9\,filesize=20M -Dsolr.jetty.inetaccess.includes= -Dsolr.jetty.inetaccess.excludes= -DzkClientTimeout=30000 -DzkRun -Dsolr.log.dir=/usr/src/solr-9.1.1/server/logs -Djetty.port=8983 -DSTOP.PORT=7983 -DSTOP.KEY=solrrocks -Duser.timezone=UTC -XX:-OmitStackTraceInFastThrow -XX:OnOutOfMemoryError=/usr/src/solr-9.1.1/bin/oom_solr.sh\ 8983\ /usr/src/solr-9.1.1/server/logs -Djetty.home=/usr/src/solr-9.1.1/server -Dsolr.solr.home=/usr/src/solr_cores -Dsolr.data.home= -Dsolr.install.dir=/usr/src/solr-9.1.1 -Dsolr.default.confdir=/usr/src/solr-9.1.1/server/solr/configsets/_default/conf -Dsolr.jetty.host=0.0.0.0 -Xss256k -XX:CompileCommand=exclude\,com.github.benmanes.caffeine.cache.BoundedLocalCache::put -Djava.security.manager -Djava.security.policy=/usr/src/solr-9.1.1/server/etc/security.policy -Djava.security.properties=/usr/src/solr-9.1.1/server/etc/security.properties -Dsolr.internal.network.permission=\* -DdisableAdminUI=false -jar /usr/src/solr-9.1.1/server/start.jar --module=http --module=requestlog --module=gzip"
    ;;
esac

# create volume for the app group
docker volume create $APP_GROUPNAME

# start container
case $APPNAME in
  solr)
    # solr requires the host machine to download the data (14GB) from cloudsuite by first running "docker run --name web_search_dataset cloudsuite/web-search:dataset" once
    if [ $( docker ps -a -f name=web_search_dataset | wc -l ) -eq 2 ]; then
      echo "dataset exists"
    else
      echo "dataset does not exist, downloading"
      docker run --name web_search_dataset cloudsuite/web-search:dataset
    fi
    # must mount dataset volume for server and docker to start querying
    docker run -dit --privileged --name $APP_GROUPNAME -v $APP_GROUPNAME:/home/memtrace -v /var/run/docker.sock:/var/run/docker.sock --volumes-from web_search_dataset $APP_GROUPNAME:latest /bin/bash
    docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "/entrypoint.sh"
    docker exec -it -d --privileged $APP_GROUPNAME /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
    ;;
  *)
    docker run -dit --privileged --name $APP_GROUPNAME -v $APP_GROUPNAME:/home/memtrace $APP_GROUPNAME:latest /bin/bash
    ;;
esac
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
    solr)
      echo "trace solr"
      # TODO: Java does not work under DynamoRIO
      # https://github.com/DynamoRIO/dynamorio/commits/i3733-jvm-bug-fixes does not work: "DynamoRIO Cache Simulator Tracer interval crash at PC 0x00007fe16d8e8fdb. Please report this at https://dynamorio.org/issues"
      # Scarab does not work either: "setarch: failed to set personality to x86_64: Operation not permitted"
      # Solr uses many threads and seems to run too long on simpoint's fingerprint collection
      docCommand+="-disable_traces -no_hw_cache_consistency -no_sandbox_writes -no_enable_reset -sandbox2ro_threshold 0 -ro2sandbox_threshold 0 -t drcachesim -offline -trace_after_instrs 100M -exit_after_tracing 101M -outdir ./ -- $BINCMD "
      # docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      cleanup="rm -rf traces/README.md traces/solr-webapp traces/start.jar traces/contexts/ traces/etc traces/lib traces/logs/ traces/modules/ traces/resources/ traces/scripts/ traces/solr/"
      cleanup+=" exp/README.md exp/solr-webapp exp/start.jar exp/contexts/ exp/etc exp/lib exp/logs/ exp/modules/ exp/resources/ exp/scripts/ exp/solr/"
      cleanup+="; docker rm web_search_client"
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
    dss)
      echo "trace dss"
      docCommand+="-t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- $BINCMD "
      ;;
    httpd)
      echo "trace httpd"
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
  # redo query setup
  if [ $COLLECTTRACES ]; then
    case $APPNAME in
      solr)
        docker rm web_search_client
        docker exec -it -d --privileged $APP_GROUPNAME /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
        ;;
    esac
  fi
  # run scripts for simpoint
  # docker exec -dit --privileged $APP_GROUPNAME /home/memtrace/run_simpoint.sh $APP_GROUPNAME &
  docker exec -it --privileged $APP_GROUPNAME /home/memtrace/run_simpoint.sh "$APPNAME" "$APP_GROUPNAME" "$BINCMD" "$SCARABPARAMS" "$TRACE_BASED"
fi

echo "copy results.."
# copy traces
if [ $COLLECTTRACES ]; then
  docker cp $APP_GROUPNAME:/home/memtrace/traces $OUTDIR
fi
# copy Scarab results
docker cp $APP_GROUPNAME:/home/memtrace/exp $OUTDIR
# solr requires extra cleanup
case $APPNAME in
  solr)
    # TODO: make it inside docker file?
    $cleanup
  ;;
esac

# remove docker container
# TODO: may not want to remove immediately -- in case of running multiple apps using same image/container
docker rm $APP_GROUPNAME

# remove docker volume
# TODO: may not want to remove immediately -- in case of running multiple apps using same image/container
docker volume rm $APP_GROUPNAME
