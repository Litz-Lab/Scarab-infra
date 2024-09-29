#!/bin/bash

source /usr/local/bin/utilities.sh

FPFILE=$1
OUTDIR=$2

cd $OUTDIR
mkdir -p simpoints

lines=($(wc -l $FPFILE))
# intended to round to nearest int
# but in fact it is just rouding down
maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
echo "fingerprint size: $lines, maxk: $maxK"
# binary search with maxK
spCmd="$tmpdir/simpoint -maxK $maxK -fixedLength off -numInitSeeds 10 -loadFVFile $FPFILE -saveSimpoints $OUTDIR/simpoints/opt.p -saveSimpointWeights $OUTDIR/simpoints/opt.w -saveVectorWeights $OUTDIR/simpoints/vector.w -saveLabels $OUTDIR/simpoints/opt.l -coveragePct .99 &> $OUTDIR/simpoints/simp.opt.log"
# search every one with maxK
# spCmd="$tmpdir/simpoint -k 1:$maxK -fixedLength off -numInitSeeds 1000 -loadFVFile $FPFILE -saveSimpoints $OUTDIR/simpoints/opt.p -saveSimpointWeights $OUTDIR/simpoints/opt.w -saveVectorWeights $OUTDIR/simpoints/vector.w -saveLabels $OUTDIR/simpoints/opt.l -coveragePct .99 &> $OUTDIR/simpoints/simp.opt.log"
echo "cluster fingerprint..."
echo "command: ${spCmd}"
start=`date +%s`
eval $spCmd
end=`date +%s`
report_time "clustering" "$start" "$end"