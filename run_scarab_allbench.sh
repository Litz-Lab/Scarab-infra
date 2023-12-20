#!/bin/bash
set -x #echo on

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
# 10M warmup by default
WARMUP=10000000

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
  *)
    echo "unknown application"
    ;;
esac


# TODO: get all cmd for spec in advance instead of in place
# Get command to run for Spe17
if [ "$APP_GROUPNAME" == "spec2017" ]; then
  # environment
  cd $tmpdir/cpu2017
  source ./shrc
  # compile and get command for application
  # TODO: this is just for one input
  ./bin/specperl ./bin/harness/runcpu --copies=1 --iterations=1 --threads=1 --config=memtrace --action=runsetup --size=train $APPNAME
  ogo $APPNAME run
  # TODO: the input size
  cd run_base_train*
  BINCMD=$(specinvoke -nn | tail -2 | head -1)
  for sub in $BINCMD; do
    if [[ -f $sub ]]; then
      # ref
      # https://stackoverflow.com/a/13210909
      # https://stackoverflow.com/a/7126780
      replace=$(readlink -f "$sub")
      BINCMD="${BINCMD/"$sub"/"$replace"}"
    fi
  done
fi

SCARABHOME=$HOME/scarab/

if [ "$SCARABMODE" == "4" ]; then
  SIMHOME=$HOME/simpoint_flow/simulations/$APPNAME
  mkdir -p $SIMHOME
  TRACEHOME=/simpoint_traces/$APPNAME

  cd $SIMHOME
  mkdir $SCENARIONUM

  cd $TRACEHOME/traces/whole
  # continue if only one trace file
  numTrace=$(find -name "dr*.trace.zip" | grep "drmemtrace.*.trace.zip" | wc -l)
  numDrFolder=$(find -type d -name "drmemtrace.*.dir" | grep "drmemtrace.*.dir" | wc -l)
  if [ "$numTrace" == "1" ] && [ "$numDrFolder" == "1" ]; then
    ###HEERREEE prepare raw dir, trace dir
    SPDIR=$TRACEHOME/simpoints/
    OUTDIR=$SIMHOME/$SCENARIONUM/
    modulesDir=$(dirname $(ls $TRACEHOME/traces/whole/drmemtrace.*.dir/raw/modules.log))
    wholeTrace=$(ls $TRACEHOME/traces/whole/drmemtrace.*.dir/trace/dr*.zip)
    echo "modulesDIR: $modulesDir"
    echo "wholeTrace: $wholeTrace"

    segmentSizeFile="$TRACEHOME/fingerprint/segment_size"
    if [ ! -f $segmentSizeFile ]
    then
            echo "$segmentSizeFile does not exist"
            exit
    fi
    SEGSIZE=$(cat "$segmentSizeFile")
    echo "SEGSIZE read from $segmentSizeFile is $SEGSIZE"
    bash run_scarab_mode_4_allbench.sh "$SCARABHOME" "$MODULESDIR" "$TRACEFILE" "$SCARABPARAMS" "$SPDIR" "$SEGSIZE" "$OUTDIR" "$WARMUP"
  else
  # otherwise ask the user to run manually
    echo -e "There are multiple trace files.\n\
    Decide and run \"/usr/local/bin/run_scarab_mode_4_allbench.sh <SCARABHOME> <MODULESDIR> <TRACEFILE> "<SCARABPARAMS>" <SPDIR> <SEGSIZE> <OUTDIR> <WARMUP>\""
    exit
  fi
elif [ "$SCARABMODE" == "3" ]; then
  SIMHOME=$HOME/simpoint_flow/simulations/$APPNAME
  EVALHOME=$HOME/simpoint_flow/evaluations/$APPNAME
  mkdir -p $SIMHOME
  mkdir -p $EVALHOME
  TRACEHOME=/simpoint_traces/$APPNAME
  ################################################################
  # read in simpoint
  # ref: https://stackoverflow.com/q/56005842
  # map of cluster - segment
  declare -A clusterMap
  while IFS=" " read -r segID clusterID; do
    clusterMap[$clusterID]=$segID 
  done < $TRACEHOME/simpoints/opt.p

  ################################################################
  # trace-based or exec-driven simulations
  taskPids=()
  start=`date +%s`
  # simulation in parallel -> use map of trace file
  for clusterID in "${!clusterMap[@]}"
  do
    mkdir -p $SIMHOME/$SCENARIONUM/$clusterID
    cp $SCARABHOME/src/PARAMS.sunny_cove $SIMHOME/$SCENARIONUM/$clusterID/PARAMS.in
    cd $SIMHOME/$SCENARIONUM/$clusterID

    segID=${clusterMap[$clusterID]}
    start_inst=$(( $segID * $SEGSIZE ))
    scarabCmd="
    python3 $SCARABHOME/bin/scarab_launch.py --program=\"$BINCMD\" \
    --simdir=\"$SIMHOME/$SCENARIONUM/$clusterID\" \
    --pintool_args=\"-hyper_fast_forward_count $start_inst\" \
    --scarab_args=\"--inst_limit $SEGSIZE $SCARABPARAMS\" \
    --scarab_stdout=\"$SIMHOME/$SCENARIONUM/$clusterID/scarab.out\" \
    --scarab_stderr=\"$SIMHOME/$SCENARIONUM/$clusterID/scarab.err\" \
    --pin_stdout=\"$SIMHOME/$SCENARIONUM/$clusterID/pin.out\" \
    --pin_stderr=\"$SIMHOME/$SCENARIONUM/$clusterID/pin.err\" \
    "

    echo "simulating cluster ${clusterID}..."
    echo "command: ${scarabCmd}"
    eval $scarabCmd &
    taskPids+=($!)
  done

  echo "wait for all simulations to finish..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "simulation process $taskPid success"
    else
      echo "simulation process $taskPid fail"
      exit
    fi
  done
  end=`date +%s`
  runtime=$((end-start))
  hours=$((runtime / 3600));
  minutes=$(( (runtime % 3600) / 60 ));
  seconds=$(( (runtime % 3600) % 60 ));
  echo "simulation Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

  ################################################################
elif [ "$SCARABMODE" == "1" ] || [ "$SCARABMODE" == "2" ]; then
  SIMHOME=$HOME/nonsimpoint_flow/simultaions/$APPNAME
  EVALHOME=$HOME/nonsimpoint_flow/evaluations/$APPNAME
  mkdir -p $SIMHOME
  mkdir -p $EVALHOME
  TRACEHOME=/simpoint_traces/$APPNAME

  if [ "$SCARABMODE" == "2" ]; then
    traceMap=$(ls $TRACEHOME/traces/whole/)
  fi
  ################################################################
  # trace-based or exec-driven simulations
  taskPids=()
  start=`date +%s`
  mkdir -p $SIMHOME/$SCENARIONUM
  cp $SCARABHOME/src/PARAMS.sunny_cove $SIMHOME/$SCENARIONUM/PARAMS.in
  cd $SIMHOME/$SCENARIONUM
  if [ "$SCARABMODE" == "2" ]; then
    scarabCmd="$SCARABHOME/src/scarab --frontend memtrace --cbp_trace_r0=$TRACEHOME/traces/whole/${traceMap} --memtrace_modules_log=$TRACEHOME/traces/raw/ $SCARABPARAMS &> sim.log"
  else
    start_inst=100000000
    scarabCmd="
    python3 $SCARABHOME/bin/scarab_launch.py --program=\"$BINCMD\" \
      --simdir=\"$SIMHOME/$SCENARIONUM/\" \
      --pintool_args=\"-hyper_fast_forward_count $start_inst\" \
      --scarab_args=\"--inst_limit $SEGSIZE $SCARABPARAMS\" \
      --scarab_stdout=\"$SIMHOME/$SCENARIONUM/scarab.out\" \
      --scarab_stderr=\"$SIMHOME/$SCENARIONUM/scarab.err\" \
      --pin_stdout=\"$SIMHOME/$SCENARIONUM/pin.out\" \
      --pin_stderr=\"$SIMHOME/$SCENARIONUM/pin.err\" \
      "
  fi
  echo "simulating ..."
  echo "command: ${scarabCmd}"
  eval $scarabCmd &
  taskPids+=($!)

  echo "wait for all simulations to finish..."
  for taskPid in ${taskPids[@]}; do
    if wait $taskPid; then
      echo "simulation process $taskPid success"
    else
      echo "simulation process $taskPid fail"
      exit
    fi
  done
  end=`date +%s`
  runtime=$((end-start))
  hours=$((runtime / 3600));
  minutes=$(( (runtime % 3600) / 60 ));
  seconds=$(( (runtime % 3600) % 60 ));
  echo "simulation Runtime: $hours:$minutes:$seconds (hh:mm:ss)"

  ################################################################
fi