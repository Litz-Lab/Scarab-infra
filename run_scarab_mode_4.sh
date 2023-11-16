#!/bin/bash

source utilities.sh

SCARABHOME=$1
MODULESDIR=$2
TRACEFILE=$3
SCARABPARAMS=$4
SPDIR=$5
SEGSIZE=$6
OUTDIR=$7
WARMUP=$8

cd $OUTDIR

################################################################
# read in simpoint
# ref: https://stackoverflow.com/q/56005842
# map of cluster - segment
declare -A clusterMap
while IFS=" " read -r segID clusterID; do
clusterMap[$clusterID]=$segID 
done < $SPDIR/opt.p

################################################################
# trace-based simulations
taskPids=()
start=`date +%s`
# simulation in parallel
# actually array would suffice
for clusterID in "${!clusterMap[@]}"
do
    segID=${clusterMap[$clusterID]}
    mkdir -p $OUTDIR/$segID
    cp $SCARABHOME/src/PARAMS.sunny_cove $OUTDIR/$segID/PARAMS.in
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

    scarabCmd="$SCARABHOME/src/scarab \
    --frontend memtrace \
    --cbp_trace_r0=$TRACEFILE \
    --memtrace_modules_log=$MODULESDIR \
    --memtrace_roi_begin=$roiStart \
    --memtrace_roi_end=$roiEnd \
    --inst_limit=$instLimit \
    --full_warmup=$WARMUP \
    $SCARABPARAMS \
    &> sim.log"

    echo "simulating clusterID ${clusterID}, segment $segID..."
    echo "command: ${scarabCmd}"
    eval $scarabCmd &
    taskPids+=($!)
    cd -
done

wait_for "simpoint simiulations" "${taskPids[@]}"
end=`date +%s`
report_time "simpoint simiulations" "$start" "$end"

# aggregate the simulation results
cd $OUTDIR
python3 /home/dcuser/gather_cluster_results.py $SPDIR $OUTDIR
