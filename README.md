# dcworkloads-dockerfiles
Dockerfiles of docker images running data center workloads

## Docker setup
Install Docker based on the instructions from official [docker docs](https://docs.docker.com/get-docker/). You can find the commands to download and run a container [here](https://docs.docker.com/engine/reference/commandline/run/).

## Requirements
To run scarab_hlitz in a docker container, the host machine should have ssh private key ~/.ssh/id_rsa permitted to clone 'scarab_hlitz' github repository.
Only use this for images that are private and will always be! The private key will be visible in the container.

To run the SPEC2017 benchmarks, the host machine should have the image `cpu2017-1_0_5.iso` under `SPEC2017/`.

## Build a Docker image and run a container of a built image

### By using a script
#### Usage
```
Usage: ./run_scarab.sh [ -h | --help ]
                [ -o | --outdir ]
                [ -t | --collect_traces]
                [ -b | --build]
                [ -s | --simpoint ]
                [ -m | --mode]

!! Modify 'apps.list' and 'params.new' to specify the apps and Scarab parameters before run !!
Options:
h     Print this Help.
o     Output directory (-o <DIR_NAME>) e.g) -o .
t     Collect traces. 0: Run without collecting traces, 1: with collecting traces e.g) -t 0
b     Build a docker image. 0: Run a container of existing docker image without bulding an image, 1: with building image. e.g) -b 1
s     SimPoint workflow. 0: Not run simpoint workflow, 1: simpoint workflow - instrumentation first (Collect fingerprints, do simpoint clustering, trace/simulate) 2: simpoint workflow - post-processing (trace, collect fingerprints, do simpoint clustering, simulate). e.g) -s 1
m     Simulation mode. 0: execution-driven simulation 1: trace-based simulation. e.g) -m 1
```
There are two ways to run Scarab: 1) execution-driven (-m 0) 2) trace-based (-m 1). The execution-driven simulation runs the application binary directly without using traces while the trace-based simulation needs collected traces to run the application. The trace-based run will collect the traces based on the given workflow (simpoint/nosimpoint) and simulate by using the traces.
You need to provide the list of the applications you want to run in 'apps.list' file, and the list of the Scarab parameters to overwrite the sunny cove default PARAMS.in in 'params.new'. Each line in 'params.new' should represent SENARIONUM,SCARABPARAMS. Please refer to the 'apps.list' and 'params.new' files for the examples.

#### Example command (Build the image from the beginning and run the application with trace-base mode by collecting the traces without simpoint methodology. Copy the collected traces and the simulation results to host after the run.)
```
$ ./run_scarab.sh -o . -t 1 -b 1 -s 0 -m 1
```
### Step-by-step on an interactive attachment
#### Build an image
```
$ docker build . -f ./example/Dockerfile --no-cache -t example:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
```
#### Check the built image
```
$ docker images
REPOSITORY                   TAG       IMAGE ID       CREATED        SIZE
example                      latest    1dd7a6097ef0   3 hours ago    6.66GB
```

#### Run a container of the image
'docker run' will stop the container after it runs the given command. Run with -v to create a volume and keep the updates inside the container remain. 'docker start' after the run will start the container again. You can run other commands inside the container by running 'docker exec'
```
docker run -dit --privileged --name example -v example:/home/dcuser example:latest /bin/bash
docker start example
```

## Developers
When you add an application support of a docker image, please expand ‘run_scarab.sh’ and 'setup_apps.sh' scripts so that the memtraces and Scarab results can be provided by running a single script. The rule of thumb is 1) to try to build a simple image where the basic essential packages are installed on a proper Ubuntu version (the first version of Dockerfile), 2) to run a container of the image, 3) to run the application, 4) to run the application with DynamoRIO (if 3) works), 5) to run Scarab with memtrace frontend feeding the collected traces from 4). 
If all 1) to 5) steps are working, you can add the processes you added after 1) to the Dockerfile and expand the script. Make sure that running the script provides the same environment and results as 1~5 steps.

## Notes
* DaCapo (cassandra, kafka, tomcat) - DynamoRIO, Scarab, and applications are successfully running, but DynamoRIO doesn't support jvm applications. memtraces cannot be collected. Only execution-driven simulation available.
* Renaissance (chirper, http)
* HHVM OSS (drupal7, mediawiki, wordpress) - Scarab complilation failed.
* SPEC2017 - only 502.gcc_r has been added. The SimPoint flow fixes the input size to `train` and the segment size to `100000000`.
* Verilator - setup based on https://github.com/efeslab/ispy-ripple. Clustering aborted due to out of memory.
