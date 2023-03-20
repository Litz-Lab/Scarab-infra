# dcworkloads-dockerfiles
Dockerfiles of docker images running data center workloads

Build an image
```
surim@ohm:~/src/dcworkloads-dockerfiles $ ./build_image.sh
Input application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress)
template
Input image name and tag (e.g. cassandra:latest)
test_template
[+] Building 159.8s (26/26) FINISHED
 => [internal] load .dockerignore                                                                                                                                                                                                   0.0s
 => => transferring context: 2B                                                                                                                                                                                                     0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                                                0.0s
 => => transferring dockerfile: 260B                                                                                                                                                                                                0.0s
 => resolve image config for docker.io/edrevo/dockerfile-plus:latest                                                                                                                                                                0.6s
 => [auth] edrevo/dockerfile-plus:pull token for registry-1.docker.io                                                                                                                                                               0.0s
 => CACHED docker-image://docker.io/edrevo/dockerfile-plus@sha256:d234bd015db8acef1e628e012ea8815f6bf5ece61c7bf87d741c466919dd4e66                                                                                                  0.0s
 => local://dockerfile                                                                                                                                                                                                              0.0s
 => => transferring dockerfile: 260B                                                                                                                                                                                                0.0s
 => local://context                                                                                                                                                                                                                 0.0s
 => => transferring context: 2.67kB                                                                                                                                                                                                 0.0s
 => [internal] load build definition from Dockerfile                                                                                                                                                                                0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                   0.0s
 => [internal] load metadata for docker.io/library/ubuntu:latest                                                                                                                                                                    0.4s
 => [auth] library/ubuntu:pull token for registry-1.docker.io                                                                                                                                                                       0.0s
 => CACHED [ 1/14] FROM docker.io/library/ubuntu:latest@sha256:67211c14fa74f070d27cc59d69a7fa9aeff8e28ea118ef3babc295a0428a6d21                                                                                                     0.0s
 => [ 2/14] RUN apt-get update && apt-get install -y     python3     python3-pip     git     sudo     wget     build-essential     cmake     libboost-all-dev     libssl-dev     libprotobuf-dev     protobuf-compiler     libunw  90.4s
 => [ 3/14] RUN pip3 install gdown                                                                                                                                                                                                  3.3s
 => [ 4/14] RUN useradd -m memtrace &&     echo "memtrace:memtrace" | chpasswd &&     usermod --shell /bin/bash memtrace &&     usermod -aG sudo memtrace                                                                           0.5s
 => [ 5/14] WORKDIR /home/memtrace                                                                                                                                                                                                  0.0s
 => [ 6/14] RUN wget -q -O - https://github.com/DynamoRIO/dynamorio/releases/download/release_9.0.1/DynamoRIO-Linux-9.0.1.tar.gz | tar -xz -C /home/memtrace                                                                       11.9s
 => [ 7/14] RUN git clone https://github.com/hpsresearchgroup/scarab.git                                                                                                                                                            1.5s
 => [ 8/14] RUN pip3 install -r /home/memtrace/scarab/bin/requirements.txt                                                                                                                                                         23.8s
 => [ 9/14] RUN gdown https://drive.google.com/uc?id=1FPaVO8A6rFyiZtXymZlFiw0OjQYVWbIN && tar -xf pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux.tar.bz2                                                                   13.6s
 => [10/14] RUN export DRIO_ROOT=/home/memtrace/DynamoRIO-Linux-9.0.1                                                                                                                                                               0.5s
 => [11/14] RUN export PIN_ROOT=/home/memtrace/pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux                                                                                                                               0.4s
 => [12/14] RUN export SCARAB_ENABLE_MEMTRACE=1                                                                                                                                                                                     0.4s
 => [13/14] RUN export LD_LIBRARY_PATH=/home/memtrace/pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux/extras/xed-intel64/lib:$LD_LIBRARY_PATH                                                                                0.4s
 => [14/14] RUN export LD_LIBRARY_PATH=/home/memtrace/pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux/intel64/runtime/pincrt:$LD_LIBRARY_PATH                                                                                0.4s
 => exporting to image                                                                                                                                                                                                             11.4s
 => => exporting layers                                                                                                                                                                                                            11.4s
 => => writing image sha256:628e339dc752aa6a9049ff69e7f38cfcbca605f9c98457016000a9d47c6726e6                                                                                                                                        0.0s
 => => naming to docker.io/library/test_template
```

Check the built image
```
surim@ohm:~/src/dcworkloads-dockerfiles $ docker images
REPOSITORY                            TAG       IMAGE ID       CREATED          SIZE
test_template                         latest    628e339dc752   43 seconds ago   2.8GB
```

Run
```
surim@ohm:~/src/dcworkloads-dockerfiles $ docker run -it test_template:latest
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

memtrace@3449cbdfda28:~$ ls
DynamoRIO-Linux-9.0.1  pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux  pinplay-drdebug-3.5-pin-3.5-97503-gac534ca30-gcc-linux.tar.bz2  scarab
memtrace@3449cbdfda28:~$
```
