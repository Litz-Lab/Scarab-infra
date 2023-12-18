#!/bin/bash

# set APP_GROUPNAME
case $APPNAME in
  cassandra | kafka | tomcat)
    echo "DaCapo applications"
    APP_GROUPNAME="dacapo"
    ;;
  chirper | http)
    echo "Renaissance applications"
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
  508.namd_r | 519.lbm_r | 520.omnetpp_r | 527.cam4_r | 548.exchange2_r | 549.fotonik3d_r | clang | gcc)
    echo "spec2017"
    APP_GROUPNAME="spec2017"
    ;;
  xgboost)
    echo "xgboost"
    APP_GROUPNAME="xgboost"
    ;;
  dv_insert | dv_update | long_multi_update | simple_insert | simple_multi_update | simple_update | wildcard_index_insert | wildcard_index_query)
    echo "mongo-perf"
    APP_GROUPNAME="mongo-perf"
    ;;
  mysql | postgres)
    echo "sysbench"
    APP_GROUPNAME="sysbench"
    ;;
  memcached)
    echo "memcached"
    APP_GROUPNAME="memcached"
    ;;
  example)
    echo "example"
    APP_GROUPNAME="example"
    ;;
  allbench)
    echo "allbench"
    APP_GROUPNAME="allbench_traces"
    ;;
  *)
    APP_GROUPNAME="unknown"
    echo "unknown application"
    ;;
esac

# set BINCMD
case $APPNAME in
  cassandra | kafka | tomcat)
    BINCMD="java -jar /home/$USER/dacapo-evaluation-git+309e1fa-java8.jar $APPNAME -n 10"
    ;;
  chirper | http)
    BINCMD="java -jar /home/$USER/renaissance-gpl-0.10.0.jar finagle-$APPNAME -r 10"
    ;;
  drupal7 | mediawiki | wordpress)
    BINCMD="\$HHVM /home/$USER/oss-performance/perf.php --$APPNAME --hhvm:$(echo \$HHVM)"
    ;;
  compression)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/compression/compression_benchmark"
    ;;
  hashing)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/hashing/hashing_benchmark"
    ;;
  mem)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/libc/mem_benchmark"
    ;;
  proto)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/proto/proto_benchmark"
    ;;
  cold_swissmap | hot_swissmap)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/$APPNAME"
    BINCMD+="_benchmark"
    ;;
  empirical_driver)
    BINCMD="/home/$USER/.cache/bazel/_bazel_$USER/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/tcmalloc/empirical_driver"
    ;;
  verilator)
    BINCMD="/home/$USER/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfigN8 +cycle-count /home/$USER/rocket-chip/emulator/dhrystone-head.riscv"
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
  xgboost)
    BINCMD="python3 /home/$USER/test-arg.py"
    ;;
  dv_insert | dv_update | long_multi_update | simple_insert | simple_multi_update | simple_update | wildcard_index_insert | wildcard_index_query)
    # command to run the server
    BINCMD="/usr/bin/mongod --config /etc/mongod.conf"
    # command for the workload generator (benchmark) - TODO: automate the server-client run
    CLIENT_BINCMD="python3 /home/$USER/mongo-perf/benchrun.py -f /home/$USER/mongo-perf/testcases/$APPNAME.js -t 1"
    ;;
  clang)
    BINCMD="/home/$USER/cpu2017/benchspec/CPU/compile-538-clang.sh 538.imagick_r_train"
    ;;
  gcc)
    BINCMD="/bin/bash /home/$USER/cpu2017/bin/runcpu --config=memtrace --action=build 538.imagick_r"
    ;;
  mysql)
    BINCMD="/usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --log-error=/var/log/mysql/error.log --pid-file=53302ceef040.pid"
    CLIENT_BINCMD="sysbench /home/$USER/sysbench/src/lua/oltp_read_write.lua --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=sbtest --db-driver=mysql --tables=10 --table-size=10000 --time=600 run"
    ;;
  postgres)
    BINCMD="/usr/lib/postgresql/12/bin/postgres -D /var/lib/postgresql/12/main -c config_file=/etc/postgresql/12/main/postgresql.conf"
    CLIENT_BINCMD="sysbench /home/$USER/sysbench/src/lua/oltp_point_select.lua --pgsql-host=127.0.0.1 --pgsql-port=5432 --pgsql-user=sbtest --pgsql-password=password --db-driver=pgsql --tables=10 --table-size=10000 --time=600 run"
    ;;
  example)
    BINCMD="/home/$USER/scarab/utils/qsort/test_qsort"
    ;;
  allbench)
    echo "No BINCMD available for allbench"
    ;;
  *)
    echo "unknown application"
    ;;
esac
