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
                [ -a | --appname ]
                [ -p | --parameters ]
                [ -o | --outdir ]
                [ -t | --tracing ]
                [ -b | --build ]
                [ -sp | --simpoint ]

Options:
h     Print this Help.
a     Application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress) e.g) -a cassandra
p     Scarab parameters except for --cbp_trace_r0=<absolute/path/to/trace> --memtrace_modules_log=<absolute/path/to/modules.log>. e.g) -p '--frontend memtrace --fetch_off_path_ops 0 --fdip_enable 1 --inst_limit 999900'
o     Output directory. e.g) -o .
t     Collect traces. Run without collecting traces if not given. e.g) -t
b     Build a docker image. Run a container of existing docker image without bulding an image if not given. e.g) -b
sp    Run SimPoint workflow. Collect fingerprint, trace, simulate, and report. e.g) -sp
```
#### Build an image and run a container to collect traces and to run Scarab in a single command
```
surim@ohm:~/src/dcworkloads-dockerfiles $ ./run_scarab.sh -a template -p '--frontend memtrace --inst_limit 999900' -o . -t -b
example
[+] Building 231.6s (25/32)
 => [internal] load .dockerignore                                                                                                                                                                                                                                            0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                              0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                         0.0s
 => => transferring dockerfile: 289B                                                                                                                                                                                                                                         0.0s
 => resolve image config for docker.io/edrevo/dockerfile-plus:latest                                                                                                                                                                                                         0.7s
 => [auth] edrevo/dockerfile-plus:pull token for registry-1.docker.io                                                                                                                                                                                                        0.0s
 => CACHED docker-image://docker.io/edrevo/dockerfile-plus@sha256:d234bd015db8acef1e628e012ea8815f6bf5ece61c7bf87d741c466919dd4e66                                                                                                                                           0.0s
 => local://dockerfile                                                                                                                                                                                                                                                       0.0s
 => => transferring dockerfile: 1.03kB                                                                                                                                                                                                                                       0.0s
 => local://context                                                                                                                                                                                                                                                          0.0s
 => => transferring context: 11.61kB                                                                                                                                                                                                                                         0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                            0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                         0.0s
 => [internal] load metadata for docker.io/library/ubuntu:focal                                                                                                                                                                                                              0.4s
 => [auth] library/ubuntu:pull token for registry-1.docker.io                                                                                                                                                                                                                0.0s
 => CACHED [ 1/20] FROM docker.io/library/ubuntu:focal@sha256:24a0df437301598d1a4b62ddf59fa0ed2969150d70d748c84225e6501e9c36b9                                                                                                                                               0.0s
 => [ 2/20] RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y     python3     python3-pip     python2     git     sudo     wget     cmake     binutils     libunwind-dev     zlib1g-dev     libsnappy-dev     liblz4-dev     g++-9     g++-9-multili  69.8s
 => [ 3/20] RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 1                                                                                                                                                                                              0.4s
 => [ 4/20] RUN pip3 install gdown                                                                                                                                                                                                                                           4.3s
 => [ 5/20] RUN useradd -m memtrace &&     echo "memtrace:memtrace" | chpasswd &&     usermod --shell /bin/bash memtrace &&     usermod -aG sudo memtrace                                                                                                                    0.5s
 => [ 6/20] WORKDIR /home/memtrace                                                                                                                                                                                                                                           0.0s
 => [ 7/20] RUN git clone --recursive https://github.com/DynamoRIO/dynamorio.git && cd dynamorio && git reset --hard release_9.0.1 && mkdir build && cd build && cmake .. && make -j 40                                                                                     63.8s
 => [ 8/20] RUN git clone https://github.com/hpsresearchgroup/scarab.git                                                                                                                                                                                                     1.7s
 => [ 9/20] RUN pip3 install -r /home/memtrace/scarab/bin/requirements.txt                                                                                                                                                                                                  30.1s
 => [10/20] RUN gdown https://drive.google.com/uc?id=1FPaVO8A6rFyiZtXymZlFiw0OjQYVWbIN && tar -xf pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux.tar.bz2                                                                                                            13.5s
 => [11/20] RUN cd /home/memtrace/scarab/src &&     make                                                                                                                                                                                                                   157.1s
 => [12/20] RUN mkdir /home/memtrace/exp                                                                                                                                                                                                                                     0.4s
 => [13/20] RUN cp /home/memtrace/scarab/src/PARAMS.kaby_lake /home/memtrace/exp/PARAMS.in                                                                                                                                                                                   0.4s
 => [internal] load build context                                                                                                                                                                                                                                            0.0s
 => => transferring context: 3.84kB
```
#### Build a Docker image of an application
Use b option
```
./run_scarab.sh -a example -p '--frontend memtrace --inst_limit 999900' -o . -b
```
#### Collect memtraces of an application
A built image should exist already.
```
./run_scarab.sh -a example -p '--frontend memtrace --inst_limit 999900' -o . -t
```

### Run the SimPoint flow for an application
A built image should exist already.
```
./run_scarab.sh -a 502.gcc_r -sp -p '--mtage_realistic_sc_40k 1' -o . -t
```

#### Run a container of a built image
A built image should exist already.
```
./run_scarab.sh -a example -p '--frontend memtrace --inst_limit 999900' -o .
```

### Step-by-step on an interactive attachment
#### Build an image
```
docker build . -f ./example/Dockerfile --no-cache -t example:latest
```
#### Check the built image
```
surim@ohm:~/src/dcworkloads-dockerfiles $ docker images
REPOSITORY                            TAG       IMAGE ID       CREATED          SIZE
example                         latest    628e339dc752   43 seconds ago   2.8GB
```

#### Run a container of the image
```
docker run -it --privileged --name example -v example:/home/memtrace example:latest /bin/bash
```

## Developers
When you add an application support of a docker image, please expand ‘run_scarab.sh’ script so that the memtraces and Scarab results can be provided by running a single script. The rule of thumb is 1) to try to build a simple image where the basic essential packages are installed on a proper Ubuntu version (the first version of Dockerfile), 2) to run a container of the image, 3) to run the application, 4) to run the application with DynamoRIO (if 3) works), 5) to run Scarab with memtrace frontend feeding the collected traces from 4). 
If all 1) to 5) steps are working, you can add the processes you added after 1) to the Dockerfile and expand the script. Make sure that running the script provides the same environment and results as 1~5 steps.

## Notes
* DaCapo (cassandra, kafka, tomcat) - DynamoRIO, Scarab, and applications are successfully running, but DynamoRIO doesn't support jvm applications. memtraces cannot be collected. Only execution-driven simulation available.
* Renaissance (chirper, http)
* HHVM OSS (drupal7, mediawiki, wordpress) - Scarab complilation failed.
* SPEC2017 - only 502.gcc_r has been added. The SimPoint flow fixes the input size to `train` and the segment size to `100000000`.
* Verilator - setup based on https://github.com/efeslab/ispy-ripple. Clustering aborted due to out of memory.
