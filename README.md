# Scarab-infra
scarab-infra is a set of tools that automate the execution of Scarab simulations. It utilizes [Docker](https://www.docker.com/) and Slurm [link] to effectively simulate applications according to the [SimPoint](https://cseweb.ucsd.edu/~calder/simpoint/) methodology. Furthermore, scarab-infra provides tools to analyze generated simulation statistics and to obtain simpoints and execution traces from binary applications.

## Requirements
1. Install Docker [docker docs](https://docs.docker.com/engine/install/).
2. Configure Docker to run as non-root user ([ref](https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue)):
   ```
   sudo chmod 666 /var/run/docker.sock
   ```
3. Add the SSH key of the machine(s) running the Docker container to your Github account ([link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux)).
4. Place simpointed instruction traces into $SIMPOINT_TRACES_DIR. scarab-infra offers prepackaged traces that can be downloaded as follows:
```
cd $SIMPOINT_TRACES_DIR
gdown https://drive.google.com/uc?id=1tfKL7wYK1mUqpCH8yPaPVvxk2UIAJrOX
tar -xzvf simpoint_traces.tar.gz
```
5. Optional: Install Slurm [link]

## Set up the environment (Docker image)
### Alternative 1: Download a pre-built Docker image with preinstalled Scarab
[TODO}

### Alternative 2: Build your own Docker image
```
cd scarab-infra
./run.sh -b $IMAGE_NAME
```

## List available workloads
```
./run.sh -l $SIMPOINT_TRACES_DIR
```

## Run a Scarab experiment
1. Setup a new experiment descriptor
```
cp json/exp.json your_experiment.json
```
2. Edit your_experiment.json to describe your experiment. You need to provide paths to
a) the path to your $IMAGE_NAME
b) the local output directory mounted to docker into which the simulation generated outputs will be placed
c) the local directory containing the traces ($SIMPOINT_TRACES_DIR)
d) the workload(s) to be executed
e) the machine parameters of the simulated microarchitecture
a) OPTIONAL: the local path to the scarab binary used for the experiment. If not provided, the default scarab binary within the Docker file will be used.  
3. Run all experiments
```
./run.sh -x your_experiment.json
```
The script will launch all Scarab simulations in parallel (one process per simpoint). You can check if the experiment is complete if there are no active scarab process running (UNIX 'top' command).


## Run a Scarab experiment via Slurm
scarab-infra utilizes Slurm a) to enable a scheduler that runs only one Scarab simulation per core at a time reducing the memory footprint and context switching overheads and b) to allow distribution of simulation runs across multiple nodes in a cluster.
1. Setup Slurm [TODO]
2. Setup your json experiment as above
3. Run all experiments via slurm
```
./run.sh --slurm your_experiment.json
```

### 4. Modify Scarab source code and rebuild the binary
A user can update scarab and rebuild for further simulation. Scarab can be updated either 'inside' or 'outside' the container. To exploit already-set simulation/building environment, scarab build itself should be done 'inside' the container.
When you modify scarab outside the container, cd to the path you provided with -sp when you launch the container, and modify it.
1. Alternative 1: Start an interactive container with preinstalled Scarab environment
```
./run.sh --interactive $IMAGE_NAME
cd /home/$USER/scarab/src
```
Alternative 2: Start an interactive container with preinstalled Scarab environment using slurm
```
./run.sh --slurm_interactive $IMAGE_NAME
cd /home/$USER/scarab/src
```
Then outside the container, you can build the updated scarab with:
```
docker exec --user=$USER --privileged $WORKLOAD_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
```
For example,
```
docker exec --user=$USER --privileged allbench_traces\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
```

### 5. Clean up any cached docker container/image/builds
```
docker stop allbench_traces_$USER
docker rm allbench_traces_$USER
docker rmi allbench_traces:$GITHASH
docker system prune
```

## Developers
When you add an application support of a docker image, please expand 'setup_apps.sh' script and 'run.sh' if needed so that the memtraces and Scarab results can be provided by running a single script. The rule of thumb is 1) to try to build a simple image where the basic essential packages are installed on a proper Ubuntu version (the first version of Dockerfile), 2) to run a container of the image, 3) to run the application, 4) to run the application with DynamoRIO (if 3) works), 5) to run Scarab with memtrace frontend feeding the collected traces from 4). 
If all 1) to 5) steps are working, you can add the processes you added after 1) to the Dockerfile and expand the script. Make sure that running the script provides the same environment and results as 1~5 steps.

An example commit for adding xgboost : https://github.com/5surim/dcworkloads-dockerfiles/commit/3a22b2ebc4620027a1c475a1ef33b67aa85376d8

An example commit for adding mongo-perf : https://github.com/5surim/dcworkloads-dockerfiles/commit/80f7f9003f8f198eadcb16bc890a2be3ba8619a5

## Notes
* DaCapo (cassandra, kafka, tomcat) - DynamoRIO, Scarab, and applications are successfully running, but DynamoRIO doesn't support jvm applications. memtraces cannot be collected. Only execution-driven simulation available.
* Renaissance (chirper, http)
* HHVM OSS (drupal7, mediawiki, wordpress) - Scarab complilation failed.
* SPEC2017 - only 502.gcc_r has been added. The SimPoint flow fixes the input size to `train` and the segment size to `100000000`.
* Verilator - setup based on https://github.com/efeslab/ispy-ripple. Clustering aborted due to out of memory.

# Publications

```
@inproceedings{oh2024udp,
  author = {Oh, Surim and Xu, Mingsheng and Khan, Tanvir Ahmed and Kasikci, Baris and Litz, Heiner},
  title = {UDP: Utility-Driven Fetch Directed Instruction Prefetching},
  booktitle = {Proceedings of the 51st International Symposium on Computer Architecture (ISCA)},
  series = {ISCA 2024},
  year = {2024},
  month = jun,
}
```
