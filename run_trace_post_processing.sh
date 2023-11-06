#!/bin/bash

source /home/dcuser/utilities.sh

OUTDIR=$1
MODULESDIR=$2
TRACEFILE=$3
SEGSIZE=$4

cd $OUTDIR
mkdir -p fingerprint

numChunk=$(unzip -l $TRACEFILE | grep "chunk." | wc -l)
echo "total number of segments/chunks: $numChunk"

# post-processing
taskPids=()
start=`date +%s`

cd fingerprint
mkdir -p pieces

for chunkID in $(seq 0 $(( $numChunk-1 )))
do
  mkdir -p $chunkID
  # do not care about the params file
  cd $chunkID
  scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace \
            --cbp_trace_r0=$TRACEFILE \
            --memtrace_modules_log=$MODULESDIR \
            --mode=trace_bbv_distributed \
            --chunk_instr_count=$SEGSIZE \
            --memtrace_roi_begin=$(( $chunkID * $SEGSIZE + 1 )) \
            --memtrace_roi_end=$(( $chunkID * $SEGSIZE + $SEGSIZE )) \
            --trace_bbv_output=$OUTDIR/fingerprint/pieces/chunk.$chunkID \
            &> sim.log"
  echo "processing chunkID ${chunkID}..."
  echo "command: ${scarabCmd}"
  eval $scarabCmd &
  taskPids+=($!)
  cd -

  # control the number of processing in paralell
  if [ "${#taskPids[@]}" -gt 40 ]; then
    echo "post-processing reaches 40 tasks, wait"
    if wait ${taskPids[0]}; then
      echo "${taskPids[0]} success"
    else
      echo "${taskPids[0]} fail"
    fi
    taskPids=("${taskPids[@]:1}")
  fi

done

wait_for "post-processing" "${taskPids[@]}"
end=`date +%s`
report_time "post-processing" "$start" "$end"

# aggregate the fingerprint pieces
cd /home/dcuser
python3 ./gather_fp_pieces.py $OUTDIR/fingerprint/pieces $numChunk
cp $OUTDIR/fingerprint/pieces/bbfp $OUTDIR/fingerprint/bbfp