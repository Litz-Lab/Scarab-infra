#!/bin/bash

source /usr/local/bin/utilities.sh

FPFILE=$1
OUTDIR=$2

cd $OUTDIR
mkdir -p simpoints

lines=($(wc -l $FPFILE))
# round to nearest int
maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
echo "fingerprint size: $lines, maxk: $maxK"
spCmd="$tmpdir/simpoint -maxK $maxK -fixedLength off -numInitSeeds 1000 -loadFVFile $FPFILE -saveSimpoints $OUTDIR/simpoints/opt.p -saveSimpointWeights $OUTDIR/simpoints/opt.w -saveLabels $OUTDIR/simpoints/opt.l &> $OUTDIR/simpoints/simp.opt.log"
echo "cluster fingerprint..."
echo "command: ${spCmd}"
start=`date +%s`
eval $spCmd
end=`date +%s`
report_time "clustering" "$start" "$end"