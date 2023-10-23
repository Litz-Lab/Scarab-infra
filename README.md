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
Usage: ./run.sh [ -h | --help ]
                [ -o | --outdir ]
                [ -b | --build]
                [ -s | --simpoint ]
                [ -t | --collect_traces]
                [ -m | --mode]
                [ -c | --cleanup]

!! Modify 'apps.list' and 'params.new' to specify the apps and Scarab parameters before run !!
The entire process of simulating a data center workload is the following.
1) application setup by building a docker image (each directory represents an application group)
2) simpoint workflow to extract the representative execution of each application
3) collect traces for trace-based simulation
4) run Scarab simulation in different modes
To perform the later step, the previous steps must be performed first, meaning all the necessary options should be set at the same time. However, you can only run earlier step(s) by unsetting the later steps for debugging purposes.
Options:
h     Print this Help.
o     Output existing directory where simpoints/traces/simulation results are copied to (-o <DIR_NAME>). If not given, the results are not copied and only remain in the container. e.g) -o .
b     Build a docker image with application setup. 0: Run a container of existing docker image 1: Build cached image and run a container of the cached image, 2: Build a new image from the beginning and overwrite whatever image with the same name. e.g) -b 2
s     SimPoint workflow. 0: No simpoint workflow, 1: simpoint workflow - instrumentation first (Collect fingerprints, do simpoint clustering) 2: simpoint workflow - post-processing (trace, collect fingerprints, do simpoint clustering). e.g) -s 1
t     Collect traces. 0: Do not collect traces, 1: Collect traces based on the SimPoint workflow (-s). e.g) -t 0
m     Scarab simulation mode. 0: No simulation 1: execution-driven simulation w/o SimPoint 2: trace-based simulation w/o SimPoint (-t should be 1 if no traces exist already in the container). 3: execution-driven simulation w/ SimPoint 4: trace-based simulation w/ SimPoint e.g) -m 4
c     Clean up all the containers/volumes after run. 0: No clean up 2: Clean up e.g) -c 1
```
There are four ways to run Scarab: 1) execution-driven w/o SimPoint (-m 1) 2) trace-based w/o SimPoint (-m 2) 3) execution-driven w/ SimPoint (-m 3) 4) trace-based w/ SimPoint (-m 4). The execution-driven simulation runs the application binary directly without using traces while the trace-based simulation needs collected traces to run the application. SimPoints are used for fast-forwarding on the execution-driven run and for collecting traces/simulating on the trace-based run.
You need to provide the list of the applications you want to run in 'apps.list' file, and the list of the Scarab parameters to overwrite the sunny cove default PARAMS.in in 'params.new'. Each line in 'params.new' should represent SENARIONUM,SCARABPARAMS. Please refer to the 'apps.list' and 'params.new' files for the examples.

#### Example command (Build the image from the beginning and run the application with trace-base mode by collecting the traces without simpoint methodology. Copy the collected traces and the simulation results to host after the run.)
```
$ ./run.sh -o . -b 2 -s 0 -t 1 -m 2
```
### Step-by-step on an interactive attachment
#### Build an image
```
$ docker build . -f ./example/Dockerfile --no-cache -t example:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
```
or
```
$ ./run.sh -b 2
```
or
```
$ export APPNAME="example"
$ export BUILD=2
$ ./setup_apps.sh
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

#### Run simpoint workflow and collect traces on an existing container
```
$ ./run.sh -o . -b 0 -s 1 -t 1 -m 0
```

#### Run simulation with already collected simpoint traces on an existing container
```
$ ./run.sh -o . -b 0 -s 0 -t 0 -m 4
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
