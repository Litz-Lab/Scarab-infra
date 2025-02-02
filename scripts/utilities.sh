#!/bin/bash

# functions
wait_for () {
  # ref: https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument
  # 1: procedure name
  # 2: task list
  local procedure="$1"
  shift
  local taskPids=("$@")
  echo "${taskPids[@]}"
  echo "wait for all $procedure to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    echo "wait for $taskPid $procedure process"
    if wait $taskPid; then
      echo "$procedure process $taskPid success"
    else
      echo "$procedure process $taskPid fail"
      exit
    fi
  done
}

report_time () {
  # 1: procedure name
  # 2: start
  # 3: end
  local procedure="$1"
  local start="$2"
  local end="$3"
  local runtime=$((end-start))
  local hours=$((runtime / 3600));
  local minutes=$(( (runtime % 3600) / 60 ));
  local seconds=$(( (runtime % 3600) % 60 ));
  echo "$procedure Runtime: $hours:$minutes:$seconds (hh:mm:ss)"
}

wait_for_non_child () {
  # ref: https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument
  # 1: procedure name
  # 2: task list
  local procedure="$1"
  shift
  local taskPids=("$@")
  echo "${taskPids[@]}"
  echo "wait for all $procedure to finish..."
  # ref: https://stackoverflow.com/a/29535256
  for taskPid in ${taskPids[@]}; do
    echo "wait for $taskPid $procedure process"
    while [ -d "/proc/$taskPid" ]; do
      sleep 10 & wait $!
    done
  done
}

set_app_groupname () {
  # set APP_GROUPNAME
  case $APPNAME in
    cassandra | kafka | tomcat | jme | biojava | luindex)
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
    500.perlbench_r | 502.gcc_r | 505.mcf_r | 520.omnetpp_r | 523.xalancbmk_r | 525.x264_r | 531.deepsjeng_r | 541.leela_r | 548.exchange2_r | 557.xz_r | \
    503.bwaves_r | 507.cactuBSSN_r | 508.namd_r | 510.parest_r | 511.povray_r | 519.lbm_r | 521.wrf_r | 526.blender_r | 527.cam4_r | 538.imagick_r | 544.nab_r | 549.fotonik3d_r | 554.roms_r | \
    clang | gcc)
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
    gapbs)
      echo "gapbs"
      APP_GROUPNAME="gapbs"
      ;;
    geekbench)
      echo "geekbench"
      APP_GROUPNAME="geekbench"
      ;;
    llama)
      echo "llama"
      APP_GROUPNAME="llama"
      ;;
    rocksdb)
      echo "rocksdb"
      APP_GROUPNAME="rocksdb"
      ;;
    tailbench)
      echo "tailbench"
      APP_GROUPNAME="tailbench"
      ;;
    taobench | feedsim | django| video_transcode_bench)
      echo "DCPerf"
      APP_GROUPNAME="dcperf"
      ;;
    example)
      echo "example"
      APP_GROUPNAME="example"
      ;;
    allbench)
      echo "allbench"
      APP_GROUPNAME="allbench_traces"
      ;;
    isca2024)
      echo "isca2024"
      APP_GROUPNAME="isca2024_udp"
      ;;
    *)
      APP_GROUPNAME="unknown"
      echo "unknown application"
      ;;
  esac
}