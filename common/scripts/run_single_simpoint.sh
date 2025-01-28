#!/bin/bash

set -x #echo on

set_app_tracefile () {
  case $APPNAME in
    mysql)
      MODULESDIR=/simpoint_traces/mysql/traces/whole/drmemtrace.mysqld.123776.5088.dir/raw
      TRACEFILE=/simpoint_traces/mysql/traces/whole/drmemtrace.mysqld.123776.5088.dir/trace/drmemtrace.mysqld.123827.6272.trace.zip
      ;;
    postgres)
      MODULESDIR=/simpoint_traces/postgres/traces/whole/drmemtrace.postgres.10865.1082.dir/raw
      TRACEFILE=/simpoint_traces/postgres/traces/whole/drmemtrace.postgres.10865.1082.dir/trace/drmemtrace.postgres.10865.3710.trace.zip
      ;;
    clang)
      MODULESDIR=/simpoint_traces/clang/traces/whole/drmemtrace.clang.03072.7752.dir/raw
      TRACEFILE=/simpoint_traces/clang/traces/whole/drmemtrace.clang.03072.7752.dir/trace/drmemtrace.clang.03072.4467.trace.zip
      ;;
    gcc)
      MODULESDIR=/simpoint_traces/gcc/traces/whole/drmemtrace.cc1.04250.2989.dir/raw
      TRACEFILE=/simpoint_traces/gcc/traces/whole/drmemtrace.cc1.04250.2989.dir/trace/drmemtrace.cc1.04250.5506.trace.zip
      ;;
    mongodb)
      MODULESDIR=/simpoint_traces/mongodb/traces/whole/drmemtrace.mongod.04280.8169.dir/raw
      TRACEFILE=/simpoint_traces/mongodb/traces/whole/drmemtrace.mongod.04280.8169.dir/trace/drmemtrace.mongod.04332.7098.trace.zip
      ;;
    verilator)
      MODULESDIR=/simpoint_traces/verilator/traces/whole/raw
      TRACEFILE=/simpoint_traces/verilator/traces/whole/trace/drmemtrace.emulator-freechips.rocketchip.system-DefaultConfigN8.00025.6005.trace.zip
      ;;
    xgboost)
      MODULESDIR=/simpoint_traces/xgboost/traces/whole/drmemtrace.python3.8.00025.6828.dir/raw
      TRACEFILE=/simpoint_traces/xgboost/traces/whole/drmemtrace.python3.8.00025.6828.dir/trace/drmemtrace.python3.8.00025.0843.trace.zip
      ;;
    memcached)
      MODULESDIR=/simpoint_traces/memcached/traces/whole/drmemtrace.memcached.07432.6868.dir/raw
      TRACEFILE=/simpoint_traces/memcached/traces/whole/drmemtrace.memcached.07432.6868.dir/trace/drmemtrace.memcached.07434.0028.trace.zip
      ;;
    redis)
      MODULESDIR=/simpoint_traces/redis/traces/drmemtrace.redis-server.40792.8757.dir/raw/
      TRACEFILE=/simpoint_traces/redis/traces/drmemtrace.redis-server.40792.8757.dir/trace/drmemtrace.redis-server.40792.6868.trace.zip
      ;;
    rocksdb)
      MODULESDIR=/simpoint_traces/rocksdb/traces_simp/raw/
      TRACEFILE=/simpoint_traces/rocksdb/traces_simp/trace/
      mode="1"
      ;;
    600.perlbench_s)
      MODULESDIR=/simpoint_traces/600.perlbench_s/traces/whole/drmemtrace.perlbench_s_base.memtrace-m64.11679.5983.dir/raw
      TRACEFILE=/simpoint_traces/600.perlbench_s/traces/whole/drmemtrace.perlbench_s_base.memtrace-m64.11679.5983.dir/trace/drmemtrace.perlbench_s_base.memtrace-m64.11679.4703.trace.zip
      ;;
    602.gcc_s)
      MODULESDIR=/simpoint_traces/602.gcc_s/traces/whole/drmemtrace.sgcc_base.memtrace-m64.66312.0508.dir/raw
      TRACEFILE=/simpoint_traces/602.gcc_s/traces/whole/drmemtrace.sgcc_base.memtrace-m64.66312.0508.dir/trace/drmemtrace.sgcc_base.memtrace-m64.66312.8159.trace.zip
      ;;
    605.mcf_s)
      MODULESDIR=/simpoint_traces/605.mcf_s/traces/whole/drmemtrace.mcf_s_base.memtrace-m64.66517.6766.dir/raw
      TRACEFILE=/simpoint_traces/605.mcf_s/traces/whole/drmemtrace.mcf_s_base.memtrace-m64.66517.6766.dir/trace/drmemtrace.mcf_s_base.memtrace-m64.66517.4453.trace.zip
      ;;
    620.omnetpp_s)
      MODULESDIR=/simpoint_traces/620.omnetpp_s/traces/whole/drmemtrace.omnetpp_s_base.memtrace-m64.11305.6465.dir/raw
      TRACEFILE=/simpoint_traces/620.omnetpp_s/traces/whole/drmemtrace.omnetpp_s_base.memtrace-m64.11305.6465.dir/trace/drmemtrace.omnetpp_s_base.memtrace-m64.11305.0389.trace.zip
      ;;
    623.xalancbmk_s)
      MODULESDIR=/simpoint_traces/623.xalancbmk_s/traces/whole/drmemtrace.xalancbmk_s_base.memtrace-m64.68960.4320.dir/raw
      TRACEFILE=/simpoint_traces/623.xalancbmk_s/traces/whole/drmemtrace.xalancbmk_s_base.memtrace-m64.68960.4320.dir/trace/drmemtrace.xalancbmk_s_base.memtrace-m64.68960.4051.trace.zip
      ;;
    625.x264_s)
      MODULESDIR=/simpoint_traces/625.x264_s/traces/whole/drmemtrace.x264_s_base.memtrace-m64.69655.2784.dir/raw
      TRACEFILE=/simpoint_traces/625.x264_s/traces/whole/drmemtrace.x264_s_base.memtrace-m64.69655.2784.dir/trace/drmemtrace.x264_s_base.memtrace-m64.69655.8596.trace.zip
      ;;
    641.leela_s)
      MODULESDIR=/simpoint_traces/641.leela_s/traces/whole/drmemtrace.leela_s_base.memtrace-m64.69890.0911.dir/raw
      TRACEFILE=/simpoint_traces/641.leela_s/traces/whole/drmemtrace.leela_s_base.memtrace-m64.69890.0911.dir/trace/drmemtrace.leela_s_base.memtrace-m64.69890.6754.trace.zip
      ;;
    648.exchange2_s)
      MODULESDIR=/simpoint_traces/648.exchange2_s/traces/whole/drmemtrace.exchange2_s_base.memtrace-m64.70065.6658.dir/raw
      TRACEFILE=/simpoint_traces/648.exchange2_s/traces/whole/drmemtrace.exchange2_s_base.memtrace-m64.70065.6658.dir/trace/drmemtrace.exchange2_s_base.memtrace-m64.70065.5851.trace.zip
      ;;
    657.xz_s)
      MODULESDIR=/simpoint_traces/657.xz_s/traces/whole/drmemtrace.xz_s_base.memtrace-m64.70645.3373.dir/raw
      TRACEFILE=/simpoint_traces/657.xz_s/traces/whole/drmemtrace.xz_s_base.memtrace-m64.70645.3373.dir/trace/drmemtrace.xz_s_base.memtrace-m64.70645.7323.trace.zip
      ;;
    *)
      echo "unknown application"
      ;;
  esac
}

set_app_bincmd () {
  # set BINCMD
  case $APPNAME in
    cassandra)
      #crashes under graal when disabling JIT, default JVM seems to work
      BINCMD="java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 500000000000 -exit_after_tracing 50000000000 -dr_ops \"-disable_traces -no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    kafka)
      BINCMD="\$tmpdir/graalvm-ce-java11-22.3.1/bin/java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 200000000000 -exit_after_tracing 50000000000 -dr_ops \"-no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    tomcat)
      BINCMD="java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 200000000000 -exit_after_tracing 50000000000 -dr_ops \"-no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    jme)
      BINCMD="java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 140000000000 -exit_after_tracing 50000000000 -dr_ops \"-disable_traces -no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    biojava)
      BINCMD="java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 1500000000000 -exit_after_tracing 50000000000 -dr_ops \"-disable_traces -no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    luindex)
      BINCMD="java -Djava.compiler=NONE -jar \$tmpdir/dacapo-23.11-chopin.jar $APPNAME -n 1 -t 1"
      DRIO_ARGS="-trace_after_instrs 3000000000000 -exit_after_tracing 50000000000 -dr_ops \"-disable_traces -no_enable_reset -no_sandbox_writes -no_hw_cache_consistency\""
      ;;
    chirper | http)
      BINCMD="java -jar \$tmpdir/renaissance-gpl-0.10.0.jar finagle-$APPNAME -r 10"
      ;;
    drupal7 | mediawiki | wordpress)
      BINCMD="\$HHVM \$tmpdir/oss-performance/perf.php --$APPNAME --hhvm:$(echo \$HHVM)"
      ;;
    compression)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/compression/compression_benchmark"
      ;;
    hashing)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/hashing/hashing_benchmark"
      ;;
    mem)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/libc/mem_benchmark"
      ;;
    proto)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/proto/proto_benchmark"
      ;;
    cold_swissmap | hot_swissmap)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/$APPNAME"
      BINCMD+="_benchmark"
      ;;
    empirical_driver)
      BINCMD="\$tmpdir/.cache/bazel/_bazel_root/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/tcmalloc/empirical_driver"
      ;;
    verilator)
      BINCMD="\$tmpdir/rocket-chip/emulator/emulator-freechips.rocketchip.system-DefaultConfigN8 +cycle-count \$tmpdir/rocket-chip/emulator/dhrystone-head.riscv"
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
    500.perlbench_r | 502.gcc_r | 505.mcf_r | 520.omnetpp_r | 523.xalancbmk_r | 525.x264_r | 531.deepsjeng_r | 541.leela_r | 548.exchange2_r | 557.xz_r | \
    503.bwaves_r | 507.cactuBSSN_r | 508.namd_r | 510.parest_r | 511.povray_r | 519.lbm_r | 521.wrf_r | 526.blender_r | 527.cam4_r | 538.imagick_r | 544.nab_r | 549.fotonik3d_r | 554.roms_r)
      BINCMD="placeholder"
      ;;
    xgboost)
      BINCMD="python3 \$tmpdir/test-arg.py"
      ;;
    dv_insert | dv_update | long_multi_update | simple_insert | simple_multi_update | simple_update | wildcard_index_insert | wildcard_index_query)
      # command to run the server
      BINCMD="/usr/bin/mongod --config /etc/mongod.conf"
      # command for the workload generator (benchmark) - TODO: automate the server-client run
      CLIENT_BINCMD="python3 \$tmpdir/mongo-perf/benchrun.py -f \$tmpdir/mongo-perf/testcases/$APPNAME.js -t 1"
      ;;
    clang)
      BINCMD="/home/\$username/cpu2017/benchspec/CPU/compile-538-clang.sh 538.imagick_r_train"
      ;;
    gcc)
      BINCMD="/bin/bash /home/\$username/cpu2017/bin/runcpu --config=memtrace --action=build 538.imagick_r"
      ;;
    mysql)
      BINCMD="/usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --log-error=/var/log/mysql/error.log --pid-file=53302ceef040.pid"
      CLIENT_BINCMD="sysbench \$tmpdir/sysbench/src/lua/oltp_read_write.lua --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=sbtest --db-driver=mysql --tables=10 --table-size=10000 --time=600 run"
      ;;
    postgres)
      BINCMD="/usr/lib/postgresql/12/bin/postgres -D /var/lib/postgresql/12/main -c config_file=/etc/postgresql/12/main/postgresql.conf"
      CLIENT_BINCMD="sysbench \$tmpdir/sysbench/src/lua/oltp_point_select.lua --pgsql-host=127.0.0.1 --pgsql-port=5432 --pgsql-user=sbtest --pgsql-password=password --db-driver=pgsql --tables=10 --table-size=10000 --time=600 run"
      ;;
    gapbs)
      #TODO
      ;;
    geekbench)
      #TODO
      ;;
    llama)
      #TODO
      ;;
    rocksdb)
      ENVVAR="DB_DIR=/tmp/rocksdbtest-1000/ WAL_DIR=/tmp/rocksdbtest-1000/ NUM_KEYS=100000000"
      BINCMD="\$tmpdir/rocksdb/db_bench --benchmarks=readwhilewriting,stats --duration=300 --use_existing_db=1 --sync=1 --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache --db=/tmp/rocksdbtest-1000/ --wal_dir=/tmp/rocksdbtest-1000/ --num=100000000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=17179869184 --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 --compression_type=zstd --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 --statistics=0 --stats_per_interval=1 --stats_interval_seconds=60 --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 --threads=1 --merge_operator=\"put\" --seed=1705975943 --report_file=/tmp/benchmark_readwhilewriting.t64.log.r.csv 2>&1 | tee -a /tmp/benchmark_readwhilewriting.t64.log"
      ;;
    tailbench)
      #TODO
      ;;
    taobench)
      BINCMD="\$tmpdir/DCPerf/benchpress_cli.py run tao_bench_autoscale"
      ;;
    feedsim)
      BINCMD="\$tmpdir/DCPerf/benchpress_cli.py run feedsim_autoscale"
      ;;
    django)
      BINCMD="\$tmpdir/DCPerf/benchpress_cli.py run django_workload_default"
      ;;
    video_transcode_bench)
      BINCMD="\$tmpdir/DCPerf/benchpress_cli.py run video_transcode_bench_svt"
      ;;
    example)
      BINCMD="/home/$USER/scarab/utils/qsort/test_qsort"
      ;;
    allbench)
      echo "No BINCMD available for allbench"
      ;;
    isca2024)
      echo "No BINCMD available for isca2024 trace runs"
      ;;
    *)
      echo "unknown application"
      ;;
  esac
}

echo "Running on $(hostname)"

# TODO: for other apps?
APPNAME="$1"
APP_GROUPNAME="$2"
BINCMD="$3"
SCENARIONUM="$4"
SCARABPARAMS="$5"
# this is fixed/settled for NON trace post-processing flow.
# for trace post-processing flow, SEGSIZE is read from file
SEGSIZE=100000000
SCARABMODE="$6"
SCARABARCH="$7"
TRACESSIMP="$8"
SCARABHOME="$9"
SEGMENT_ID="$10"

if [ "$APP_GROUPNAME" == "allbench_traces" ] || [ "$APP_GROUPNAME" == "isca2024_udp" ]; then
  # 10M warmup by default
  WARMUP=10000000
else
  WARMUP=50000000
fi

set_app_bincmd
set_app_tracefile

# overwriting
if [ "$TRACESSIMP" == "1" ]; then
  MODULESDIR=/simpoint_traces/$APPNAME/traces_simp/bin
  TRACEFILE=/simpoint_traces/$APPNAME/traces_simp/trace
fi

SIMHOME=$HOME/$SCENARIONUM/$APPNAME
mkdir -p $SIMHOME
TRACEHOME=/simpoint_traces/$APPNAME

cd $SIMHOME
mkdir $SCENARIONUM

cd $TRACEHOME/traces/whole
# continue if only one trace file
###HEERREEE prepare raw dir, trace dir
SPDIR=$TRACEHOME/simpoints/
OUTDIR=$SIMHOME

segmentSizeFile="$TRACEHOME/fingerprint/segment_size"
if [ ! -f $segmentSizeFile ]
then
  echo "$segmentSizeFile does not exist"
  exit
fi
SEGSIZE=$(cat "$segmentSizeFile")
echo "SEGSIZE read from $segmentSizeFile is $SEGSIZE"


# This part comes from the beginning of run_scarab_mode_4_allbench.sh
# if TRACESSIMP is 1,
# TRACEFILE is supposed to be traces_simp FOLDER
if [ "$TRACESSIMP" == "1" ]; then
    if [ ! -d $TRACEFILE ]; then
        echo "TRACEFILE is supposed to be traces_simp FOLDER"
        exit
    fi
fi

# This part is an unrolled version of the loop int run_scarab_mode_4_allbench.sh
echo "SEGMENT ID: $segID"
segID=$SEGMENT_ID
mkdir -p $OUTDIR/$segID
cp $SCARABHOME/src/PARAMS.$SCARABARCH $OUTDIR/$segID/PARAMS.in
cd $OUTDIR/$segID

# roi is initialized by original segment boundary without warmup
roiStart=$(( $segID * $SEGSIZE + 1 ))
roiEnd=$(( $segID * $SEGSIZE + $SEGSIZE ))

# now reset roi start based on warmup:
# roiStart + WARMUP = original segment start
if [ "$roiStart" -gt "$WARMUP" ]; then
    # enough room for warmup, extend roi start to the left
    roiStart=$(( $roiStart - $WARMUP ))
else
    # no enough preceding instructions, can only warmup till segment start
    WARMUP=$(( $roiStart - 1 ))
    # new roi start is the very first instruction of the trace
    roiStart=1
fi

instLimit=$(( $roiEnd - $roiStart + 1 ))

if [ "$TRACESSIMP" != "1" ]; then
    echo "!TRACESSIMP"
    scarabCmd="$SCARABHOME/src/scarab \
    --frontend memtrace \
    --cbp_trace_r0=$TRACEFILE \
    --memtrace_modules_log=$MODULESDIR \
    --memtrace_roi_begin=$roiStart \
    --memtrace_roi_end=$roiEnd \
    --inst_limit=$instLimit \
    --full_warmup=$WARMUP \
    --use_fetched_count=1 \
    $SCARABPARAMS \
    &> sim.log"
elif [ "$TRACESSIMP" == "1" ]; then
    echo "TRACESSIMP"
    # with TRACESSIMP
    # simultion uses the specific trace file
    # the roiStart is the second chunk, which is assumed to be segment size
    #### if chunk zero chunk is part of the simulation, the roiStart is the first chunk
    # the roiEnd is always the end of the trace -- (dynamorio uses 0)
    # the warmup is the same

    # roiStart 1 means simulation starts with chunk 0
    if [ "$roiStart" == "1" ]; then
        echo "ROISTART"
        echo "$TRACEFILE"
        echo "$segID"
        scarabCmd="$SCARABHOME/src/scarab \
        --frontend memtrace \
        --cbp_trace_r0=$TRACEFILE/$segID.zip \
        --memtrace_modules_log=$MODULESDIR \
        --memtrace_roi_begin=1 \
        --memtrace_roi_end=$instLimit \
        --inst_limit=$instLimit \
        --full_warmup=$WARMUP \
        --use_fetched_count=1 \
        $SCARABPARAMS \
        &> sim.log"
    else
        echo "!ROISTART"
        scarabCmd="$SCARABHOME/src/scarab \
        --frontend memtrace \
        --cbp_trace_r0=$TRACEFILE/$segID.zip \
        --memtrace_modules_log=$MODULESDIR \
        --memtrace_roi_begin=$(( $SEGSIZE + 1)) \
        --memtrace_roi_end=$(( $SEGSIZE + $instLimit )) \
        --inst_limit=$instLimit \
        --full_warmup=$WARMUP \
        --use_fetched_count=1 \
        $SCARABPARAMS \
        &> sim.log"
    fi

fi

echo "simulating clusterID ${clusterID}, segment $segID..."
echo "command: ${scarabCmd}"
eval $scarabCmd &
wait $!

# Issues. See sim.log in new_experiment20.
# Failed to open /simpoint_traces/postgres/traces_simp/trace/postgres0.zip
# CMD:  docker exec --user aesymons --workdir /home/aesymons --privileged allbench_traces_aesymons slurm_payload.sh "postgres" "allbench_traces" "" "new_experiment20/fe_ftq_block_num.16" "--inst_limit 99900000 --fdip_enable 1 --fe_ftq_block_num 16" "4" "sunny_cove" "1" /home/aesymons/new_experiment20/scarab "3954"