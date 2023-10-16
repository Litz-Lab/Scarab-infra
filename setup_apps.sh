#!/bin/bash

# build a docker image
case $APPNAME in
  cassandra | kafka | tomcat)
    echo "build DaCapo applications"
    APP_GROUPNAME="dacapo"
    ;;
  chirper | http)
    echo "build Renaissance applications"
    APP_GROUPNAME="renaissance"
    ;;
  drupal7 | mediawiki | wordpress)
    echo "HHVM OSS-performance applications"
    APP_GROUPNAME="oss"
    ;;
  compression | hashing | mem | proto | cold_swissmap | hot_swissmap | empirical_driver)
    echo "fleetbench applications"
    APP_GROUPNAME="fleetbench"
    ;;
  verilator)
    echo "verilator"
    APP_GROUPNAME="verilator"
    ;;
  dss)
    echo "dss"
    APP_GROUPNAME="dss"
    ;;
  httpd)
    echo "httpd"
    APP_GROUPNAME="httpd"
    ;;
  solr)
    echo "solr"
    APP_GROUPNAME="solr"
    ;;
  # TODO: add all SPEC names
  508.namd_r | 519.lbm_r | 520.omnetpp_r | 527.cam4_r | 548.exchange2_r | 549.fotonik3d_r)
    echo "spec2017"
    APP_GROUPNAME="spec2017"
    ;;
  example)
    echo "example"
    APP_GROUPNAME="example"
    ;;
  *)
    APP_GROUPNAME="unknown"
    echo "unknown application"
    ;;
esac
# build from the beginning and overwrite whatever image with the same name
if [ $BUILD ]; then
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
else # find the existing cache/image and start from there
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
fi

# set BINCMD
case $APPNAME in
  cassandra | kafka | tomcat)
    BINCMD="java -jar /home/dcuser/dacapo-evaluation-git+309e1fa-java8.jar $APPNAME -n 10"
    ;;
  chirper | http)
    BINCMD="java -jar /home/dcuser/renaissance-gpl-0.10.0.jar finagle-$APPNAME -r 10"
    ;;
  drupal7 | mediawiki | wordpress)
    BINCMD="\$HHVM /home/dcuser/oss-performance/perf.php --$APPNAME --hhvm:$(echo \$HHVM)"
    ;;
  compression)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/compression/compression_benchmark"
    ;;
  hashing)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/hashing/hashing_benchmark"
    ;;
  mem)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/libc/mem_benchmark"
    ;;
  proto)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/proto/proto_benchmark"
    ;;
  cold_swissmap | hot_swissmap)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/$APPNAME"
    BINCMD+="_benchmark"
    ;;
  empirical_driver)
    BINCMD="/home/dcuser/.cache/bazel/_bazel_dcuser/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/tcmalloc/empirical_driver"
    ;;
  verilator)
    BINCMD="/home/dcuser/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfigN8 +cycle-count /home/dcuser/rocket-chip/emulator/dhrystone-head.riscv"
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
  example)
    BINCMD="for i in {1..100000000}\; do echo -n \"-\"; done"
    ;;
  *)
    echo "unknown application"
    ;;
esac

# create volume for the app group
#docker volume create $APP_GROUPNAME

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
    docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "/entrypoint.sh"
    docker exec -it -d --privileged $APP_GROUPNAME /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
    ;;
  *)
    ;;
esac
docker run -dit --privileged --name $APP_GROUPNAME -v $APP_GROUPNAME:/home/dcuser $APP_GROUPNAME:latest /bin/bash
docker start $APP_GROUPNAME
