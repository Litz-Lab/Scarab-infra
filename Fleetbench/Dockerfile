# syntax = edrevo/dockerfile-plus
FROM ubuntu:20.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python2 \
    git \
    sudo \
    wget \
    cmake \
    binutils \
    libunwind-dev \
    zlib1g-dev \
    libsnappy-dev \
    liblz4-dev \
    g++-9 \
    g++-9-multilib \
    doxygen \
    libconfig++-dev \
    clang \
    lld \
    vim

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 1

RUN pip3 install gdown

# Create a new user 'memtrace' with password 'memtrace'
RUN useradd -m memtrace && \
    echo "memtrace:memtrace" | chpasswd && \
    usermod --shell /bin/bash memtrace && \
    usermod -aG sudo memtrace

# Set the working directory
WORKDIR /home/memtrace

# Switch to the memtrace user
USER memtrace

# DynamoRIO build from source
RUN git clone --recursive https://github.com/DynamoRIO/dynamorio.git && cd dynamorio && git reset --hard release_9.0.1 && mkdir build && cd build && cmake .. && make -j 40

# Clone the Scarab repository
RUN git clone https://github.com/hpsresearchgroup/scarab.git

# Install Scarab dependencies
RUN pip3 install -r /home/memtrace/scarab/bin/requirements.txt
RUN wget https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz && tar -xzvf pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz

# Build Scarab
ENV PIN_ROOT /home/memtrace/pin-3.15-98253-gb56e429b1-gcc-linux
# TODO: need to update to 'ENV SCARAB_ENABLE_PT_MEMTRACE 1' after switching to scarab_hlitz
ENV SCARAB_ENABLE_MEMTRACE 1
ENV LD_LIBRARY_PATH /home/memtrace/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib
ENV LD_LIBRARY_PATH /home/memtrace/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:$LD_LIBRARY_PATH
RUN cd /home/memtrace/scarab/src && \
    make
RUN mkdir /home/memtrace/exp
RUN cp /home/memtrace/scarab/src/PARAMS.kaby_lake /home/memtrace/exp/PARAMS.in
COPY ./scarab_memtrace/portabilize_trace.py /home/memtrace/scarab/utils/memtrace
COPY ./scarab_memtrace/updateTraceModulePaths.py /home/memtrace/scarab/utils/memtrace
RUN mkdir /home/memtrace/traces

ENV DOCKER_BUILDKIT 1
ENV COMPOSE_DOCKER_CLI_BUILD 1


USER memtrace

# install bazel, fleetbench
RUN wget https://github.com/bazelbuild/bazelisk/releases/download/v1.16.0/bazelisk-linux-amd64
RUN chmod +x bazelisk-linux-amd64
RUN echo "memtrace" | sudo -S mv bazelisk-linux-amd64 /usr/local/bin/bazel
RUN git clone https://github.com/google/fleetbench.git
RUN cd fleetbench/

# remove version 10 of Clang/LLVM/lld, install version 14
RUN echo memtrace | sudo -S apt install -y software-properties-common
RUN echo memtrace | sudo -S apt remove -y llvm clang
RUN echo memtrace | sudo -S apt remove -y llvm-10 clang-10 lld-10
RUN echo memtrace | sudo -S bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh
RUN echo memtrace | sudo -S ./llvm.sh 14
RUN echo memtrace > pwd
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key > temp
RUN cat pwd temp | sudo -S apt-key add -
RUN echo memtrace | sudo -S apt autoremove -y
RUN echo memtrace | sudo -S add-apt-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-14 main"
RUN echo memtrace | sudo -S apt-get install clang-14
RUN echo memtrace | sudo -S update-alternatives --install /usr/bin/clang clang /usr/bin/clang-14 100
RUN echo memtrace | sudo -S update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-14 100

# final setup things, memtrace
WORKDIR /home/memtrace/fleetbench
RUN cd fleetbench
RUN echo "build --config=clang" >> .bazelrc
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/swissmap:hot_swissmap_benchmark
WORKDIR /home/memtrace
RUN cd /home/memtrace/traces && /home/memtrace/dynamorio/build/bin64/drrun -t drcachesim -offline -trace_after_instrs 100000000 -exit_after_tracing 101000000 -outdir ./ -- /home/memtrace/.cache/bazel/_bazel_memtrace/107a4c1ce14e7747be85d98e8915ea0d/execroot/com_google_fleetbench/bazel-out/k8-opt-clang/bin/fleetbench/swissmap/hot_swissmap_benchmark.runfiles/com_google_fleetbench/fleetbench/swissmap/hot_swissmap_benchmark && cd /home/memtrace/traces && read TRACEDIR < <(bash ../scarab/utils/memtrace/run_portabilize_trace.sh) && cd /home/memtrace/exp && ../scarab/src/scarab --cbp_trace_r0=../traces/$TRACEDIRtrace --memtrace_modules_log=../traces/$TRACEDIRraw --frontend memtrace --inst_limit 1000000