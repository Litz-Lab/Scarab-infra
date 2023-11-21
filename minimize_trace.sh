BINDIR=$1
TRACEFILE=$2
SPDIR=$3

# SEGSIZE is assumed to be the same as the chunk
# (simpoints are assumed to be the same size as the chunk)

# warmup is specified in the unit of chunks, e.g., 1 or 4
WARMUPCHUNKSORG=$4
# supposed to be /home/dcuser/simpoint_flow/APPNAME/simp_traces
OUTDIR=$5

# create the folders
# a single copy of bin
# unzip the first chunk + the warmup chunks + the simpoint chunk -> a segment folder

cd $OUTDIR

mkdir raw
cp -r $BINDIR bin

mkdir trace
cd trace

# read in simpoints
declare -A clusterMap
while IFS=" " read -r segID clusterID; do
clusterMap[$clusterID]=$segID
done < $SPDIR/opt.p

# create simp trace folder and unzip original trace
for clusterID in "${!clusterMap[@]}"
do
    WARMUP=$WARMUPCHUNKSORG
    segID=${clusterMap[$clusterID]}
    mkdir $segID

    # unzip /path/to/archive.zip "in/archive/folder/*" -d "/path/to/unzip/to"
    # ref: https://unix.stackexchange.com/questions/59276/how-to-extract-only-a-specific-folder-from-a-zipped-archive-to-a-given-directory

    # the simulation region, in the unit of chunks
    roiStart=$segID
    # seq is inclusive
    roiEnd=$segID

    if [ "$roiStart" -gt "$WARMUP" ]; then
        # enough room for warmup, extend roi start to the left
        roiStart=$(( $roiStart - $WARMUP ))
    else
        # no enough preceding instructions, can only warmup till segment start
        WARMUP=$roiStart
        # new roi start is the very first instruction of the trace
        roiStart=0
    fi

    # even if zero is included in the simulation region,
    # copy chunk zero to get rid of the special case handling and embrace laziness
    echo "unzipping chunk 0000"
    unzip "$TRACEFILE" "chunk.0000" -d "./$segID"

    for chunkID in $(seq $roiStart $roiEnd);
    do
        # ref: https://stackoverflow.com/questions/1117134/padding-zeros-in-a-string
        # unzip /path/to/archive.zip "in/archive/folder/*" -d "/path/to/unzip/to"
        padChunkID=$(printf %04d $chunkID)
        echo "unzipping chunk $padChunkID"
        unzip "$TRACEFILE" "chunk.$padChunkID" -d "./$segID"
    done

    # rezip the dir
    echo "zipping segment $segID"
    zip -r "./$segID.zip" "./$segID"

    # delete tmp unzipped file folder
    echo "removing tmp segment folder"
    rm -rf "./$segID"
done

# after doing this, can move around the entire folder
# then run update modules log,
# and copy bin modules log into raw folder since
# sometimes people just assume modules log is also there