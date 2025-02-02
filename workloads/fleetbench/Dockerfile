# syntax = edrevo/dockerfile-plus
FROM ubuntu:20.04

INCLUDE+ ./common/Dockerfile.common

USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y clang lld

WORKDIR $tmpdir

# install bazel, fleetbench
RUN wget https://github.com/bazelbuild/bazelisk/releases/download/v1.16.0/bazelisk-linux-amd64
RUN chmod +x bazelisk-linux-amd64
RUN mv bazelisk-linux-amd64 /usr/local/bin/bazel
RUN git clone https://github.com/google/fleetbench.git
RUN cd fleetbench/

# remove version 10 of Clang/LLVM/lld, install version 14
RUN apt install -y software-properties-common
RUN apt remove -y llvm clang
RUN apt remove -y llvm-10 clang-10 lld-10
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh
RUN ./llvm.sh 14
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key > temp
RUN cat pwd temp | sudo -S apt-key add -
RUN apt autoremove -y
RUN add-apt-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-14 main"
RUN apt-get install clang-14
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-14 100
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-14 100

# install python3.9 and needed libraries for compression benchmark
RUN add-apt-repository universe
RUN apt update
RUN apt install python3.9 -y
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
RUN pip install zstandard
RUN pip install python-snappy
RUN apt install python3-tk -y
RUN pip install numpy

# final setup things, memtrace
WORKDIR $tmpdir/fleetbench
RUN cd $tmpdir/fleetbench
RUN echo "build --config=clang" >> .bazelrc
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/compression:compression_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/hashing:hashing_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/libc:mem_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/proto:proto_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/swissmap:cold_swissmap_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/swissmap:hot_swissmap_benchmark
RUN GLIBC_TUNABLES=glibc.pthread.rseq=0 bazel build --config=opt fleetbench/tcmalloc:empirical_driver

# Start your application
CMD ["/bin/bash"]
