#!/bin/bash
CONTAINERID=$1

user=$(whoami)

docker cp ./utilities.sh $CONTAINERID:/usr/local/bin
docker cp ./run_clustering.sh $CONTAINERID:/usr/local/bin
docker cp ./run_scarab.sh $CONTAINERID:/usr/local/bin
docker cp ./run_scarab_allbench.sh $CONTAINERID:/usr/local/bin
docker cp ./run_scarab_mode_4.sh $CONTAINERID:/usr/local/bin
docker cp ./run_scarab_mode_4_allbench.sh $CONTAINERID:/usr/local/bin
docker cp ./run_simpoint_trace.sh $CONTAINERID:/usr/local/bin
docker cp ./run_trace_post_processing.sh $CONTAINERID:/usr/local/bin
docker cp ./gather_cluster_results.py $CONTAINERID:/usr/local/bin
docker cp ./gather_fp_pieces.py $CONTAINERID:/usr/local/bin
docker cp ./common/common_entrypoint.sh $CONTAINERID:/usr/local/bin
docker cp ./run_exp_using_descriptor.py $CONTAINERID:/usr/local/bin
docker cp ./gather_cluster_results_using_descriptor.py $CONTAINERID:/usr/local/bin
docker cp ./run_single_simpoint.sh $CONTAINERID:/usr/local/bin

# This script doesn't work unless chmod +x is run
docker exec --user root --workdir /home/$user --privileged $CONTAINERID chmod +x /usr/local/bin/run_single_simpoint.sh