#!/bin/bash

source utilities.sh

SCARABHOME=$1
MODULESDIR=$2
TRACEFILE=$3
SCARABPARAMS=$4
SPDIR=$5
SEGSIZE=$6
OUTDIR=$7

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

    scarabCmd="$SCARABHOME/src/scarab \
    --frontend memtrace \
    --cbp_trace_r0=$TRACEFILE \
    --memtrace_modules_log=$MODULESDIR \
    --memtrace_roi_begin=$(( $segID * $SEGSIZE + 1 )) \
    --memtrace_roi_end=$(( $segID * $SEGSIZE + $SEGSIZE )) \
    --inst_limit=$SEGSIZE \
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
