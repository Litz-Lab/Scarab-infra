#!/bin/bash

source /home/dcuser/utilities.sh

OUTDIR=$1
MODULESDIR=$2
TRACEFILE=$3
SEGSIZE=$4
CHUNKSIZE=$5

cd $OUTDIR
mkdir -p fingerprint
cd fingerprint
mkdir -p pieces

numChunk=$(unzip -l $TRACEFILE | grep "chunk." | wc -l)

# rounded-up instr count
numInsts=$(echo "$numChunk * $CHUNKSIZE" | bc)
numSegment=$(echo "1 + (($numInsts - 1) / $SEGSIZE)" | bc)
echo "total number of trace chunks $numChunk"
echo "total number of instructions ~$numInsts"
echo "initial number of segments (of size $SEGSIZE) $numSegment"
while [ "$numSegment" -lt 1000 ]; do
  echo "$numSegment is smaller than 1000, reduce SEGSIZE by 10x"

  SEGSIZE=$(echo "$SEGSIZE / 10" | bc)
  # if segsize is smaller than the chunksize, the total number of segments
  # becomes incorrect. the following steps will fail. so quit.
  if [ "$SEGSIZE" -lt "$CHUNKSIZE" ]; then
    echo "new SEGSIZE is $SEGSIZE, less than CHUNKSIZE $CHUNKSIZE, too small?? quit!"
    exit
  fi
  numSegment=$(echo "1 + (($numInsts - 1) / $SEGSIZE)" | bc)
  echo "new SEGSIZE is $SEGSIZE, new number of segments is $numSegment"
done

echo "final SEGSIZE is $SEGSIZE, written to $OUTDIR/fingerprint/segment_size"
echo "$SEGSIZE" > $OUTDIR/fingerprint/segment_size

# post-processing
taskPids=()
start=`date +%s`

for segmentID in $(seq 0 $(( $numSegment-1 )))
do
  mkdir -p $segmentID
  # do not care about the params file
  cd $segmentID
  scarabCmd="/home/dcuser/scarab/src/scarab --frontend memtrace \
            --cbp_trace_r0=$TRACEFILE \
            --memtrace_modules_log=$MODULESDIR \
            --mode=trace_bbv_distributed \
            --segment_instr_count=$SEGSIZE \
            --memtrace_roi_begin=$(( $segmentID * $SEGSIZE + 1 )) \
            --memtrace_roi_end=$(( $segmentID * $SEGSIZE + $SEGSIZE )) \
            --trace_bbv_output=$OUTDIR/fingerprint/pieces/segment.$segmentID \
            &> sim.log"
  echo "processing segmentID ${segmentID}..."
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
python3 ./gather_fp_pieces.py $OUTDIR/fingerprint/pieces $numSegment
cp $OUTDIR/fingerprint/pieces/bbfp $OUTDIR/fingerprint/bbfp