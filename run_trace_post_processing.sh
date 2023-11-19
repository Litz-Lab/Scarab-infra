#!/bin/bash

source /home/dcuser/utilities.sh

OUTDIR=$1
MODULESDIR=$2
TRACEFILE=$3
CHUNKSIZE=$4
SEGSIZE=$5

cd $OUTDIR
rm -rf fingerprint
mkdir fingerprint
cd fingerprint
mkdir pieces

numChunk=$(unzip -l $TRACEFILE | grep "chunk." | wc -l)

# rounded-up instr count
numInsts=$(echo "$numChunk * $CHUNKSIZE" | bc)

echo "total number of trace chunks $numChunk"
echo "total number of instructions ~$numInsts"

# sizeList=("100000000" "50000000" "20000000" "10000000")
# sizeList=("100000000" "10000000")
# for SEGSIZE in "${sizeList[@]}"
# do
#   numSegment=$(echo "1 + (($numInsts - 1) / $SEGSIZE)" | bc)
#   echo "with SEGSIZE $SEGSIZE, number of segments is $numSegment"
#   if [ "$numSegment" -ge 1000 ]; then
#     break
#   elif [ "$SEGSIZE" -eq "${sizeList[-1]}" ]; then
#     echo "with the smallest SEGSIZE $SEGSIZE, number of segments is still not enough for clustering. quit."
#     exit
#   fi
# done

numSegment=$(echo "1 + (($numInsts - 1) / $SEGSIZE)" | bc)
echo "with SEGSIZE $SEGSIZE, number of segments is $numSegment"
if [ "$numSegment" -lt 1000 ]; then
  echo "WARNING: with SEGSIZE $SEGSIZE, number of segments is less than 1000. Might be to few for clustering."
fi

# if segsize is smaller than the chunksize, the total number of segments
# becomes incorrect. the following steps will fail. so quit.
if [ "$SEGSIZE" -lt "$CHUNKSIZE" ]; then
  echo "SEGSIZE is $SEGSIZE, less than CHUNKSIZE $CHUNKSIZE, which is too small??"

  if [ "$OUTDIR" == "/home/dcuser/simpoint_flow/verilator/simpoint_10M" ]; then
    echo "This is a hard-coded scenario for verilator, which has chunk size > segment size"
    # verilator last chunk chunk.3945 has 35181523 instructions
    # so the total number of instruction is
    # 3945 * 100M + 35181523 (round up to 4*10M)
    # then the number of segments of 10M is
    numSegment=39454
  else
    exit
  fi
fi

echo "final SEGSIZE is $SEGSIZE, written to $OUTDIR/fingerprint/segment_size"
echo "$SEGSIZE" > $OUTDIR/fingerprint/segment_size

# post-processing
taskPids=()
start=`date +%s`

for segmentID in $(seq 0 $(( $numSegment-1 )))
do
  mkdir $segmentID
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