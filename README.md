# Scarab-infra
scarab-infra is an infrastructure that serves an environment where a user analyzes CPU metrics of a workload, applies [SimPoint](https://cseweb.ucsd.edu/~calder/simpoint/) method to exploit program phase behavior, collects execution traces, and simulates the workload by using [scarab](https://github.com/Litz-Lab/scarab) microprocessor simulator. The environment is buildable via [Docker](https://www.docker.com/).

This tool is mainly used for the following three scenarios where CPU architect works on CPU performance for datacenter workloads.
1) Simulate and evaluate a customized modern microprocessor by using scarab CPU simulator and datacenter workloads' execution traces (trace-driven simulation) + plot CPU metrics from the simulation results.
2) Run a datacenter workload itself or run scarab simulation of the workload in execution-driven mode.
3) Analyze CPU metrics of a datacenter workload, extract its program phase behavior, and collect its exection traces.

In this README, 1) and 2) are described with step-by-step instructions in a manual way.
For the instructions using Slurm workload manager, please refer to [README.Slurm.md](./docs/README.Slurm.md) for non-UCSC LitzLab users or [README.Slurm.LitzLab.md](./docs/README.Slurm.LitzLab.md).

There are four ways to run Scarab: 1) execution-driven w/o SimPoint 2) trace-based w/o SimPoint 3) execution-driven w/ SimPoint 4) trace-based w/ SimPoint. The execution-driven simulation runs the application binary directly without using traces while the trace-based simulation needs collected traces to run the application. SimPoints are used for fast-forwarding on the execution-driven run and for collecting traces/simulating on the trace-based run.
The list of the Scarab parameters should be given to generate parameter descriptor file in `<experiment_name>.json`. Please refer to the `./json/exp.json` files for the examples.

The following steps are for the fourth running scenario (trace-based w/ SimPoint) with the traces of datacenter workloads we already collected.

## Requirements
1. Install Docker based on the instructions from official [docker docs](https://docs.docker.com/engine/install/).
2. To run scarab in a docker container, the host machine should use non-root user and the user has a proper GitHub setup to access https://github.com/Litz-Lab/scarab.
To run docker as a non-root user, run ([ref](https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue)):
   ```
   sudo chmod 666 /var/run/docker.sock
   ```
Generate a new SSH key and add it to the machine's SSH agent, then add it to your GitHub account ([link](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=linux)).

## Set up the environment: build a Docker image and run a container of a built image
### 1. Build a Docker image
```
./run.sh -b $WORKLOAD_GROUPNAME
```
For example,
```
./run.sh -b allbench_traces
```

### 2. Run a Docker container by using the built image and specifying home/scarab/trace paths to be mounted on host.
For non-UCSC LitzLab users, please download the traces and place/unzip it, then provide the path with -tp.
For example (only non-UCSC LitzLab users),
```
cd /home/$USER/simpoint_traces
gdown https://drive.google.com/uc?id=1tfKL7wYK1mUqpCH8yPaPVvxk2UIAJrOX
tar -xzvf simpoint_traces.tar.gz
```
and then (all the users),
```
./run.sh -r $WORKLOAD_NAME -hp <path_to_mount_docker_home> -sp <path_to_mount_scarab_repo> -tp <path_to_mount_simpoints_traces>
```
For example for non-UCSC users,
```
./run.sh -r allbench -hp /home/$USER/allbench_home -sp /home/$USER/scarab -tp /home/$USER/simpoint_traces
```
for UCSC users,
```
./run.sh -r allbench -hp /soe/$USER/allbench_home -sp /soe/$USER/scarab -tp /soe/hlitz/lab/traces
```
This step sets up the environment within a Docker container where a workload is ready to run and Scarab simulation is ready.
`/home/$USER/allbench_home` is a path on host where scarab source codes are downloaded where a user can modify the source codes and rebuild it within the Docker container.

### 3. Run scarab trace-based simulation
The example file descriptor for all the simulation scenarios is in `json/exp.json` and `json/exp.pt.json`
The simulations using memtrace or pt traces should be launched separately with different simulation mode (4 : memtrace, 5 : PT trace). Still the two executions can be parallelized (by launching on different terminals). -w should be provided to identify applications with the same name but within different workload group.
Run the following command with <experiment> name for -e.
```
./run.sh -o /home/$USER/allbench_home -s 4 -e exp -w allbench
./run.sh -o /home/$USER/allbench_home -s 5 -e exp.pt -w allbench
```
The script will launch Scarab simulations in background until it runs all the different scenarios x workloads. You can check if all the simulations are over by checking if there is any 'scarab' process running (UNIX 'top' command).

### 4. Modify the source code and rebuild scarab
A user can update scarab and rebuild for further simulation. Scarab can be updated either 'inside' or 'outside' the container. To exploit already-set simulation/building environment, scarab build itself should be done 'inside' the container.
When you modify scarab outside the container, cd to the path you provided with -sp when you launch the container, and modify it.
```
cd /home/$USER/scarab/src
```
If you modify scarab inside the container, open an interactive shell to the docker container, cd to the path within the container, and modify it.
```
docker exec -it --user=$USER --pribileged $WORKLOAD_GROUPNAME\_$USER /bin/bash
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
