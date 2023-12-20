# syntax = edrevo/dockerfile-plus
FROM ubuntu:20.04

INCLUDE+ ./common/Dockerfile.common

USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autoconf \
    automake \
    autotools-dev \
    curl \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    libusb-1.0-0-dev \
    gawk \
    build-essential \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    device-tree-compiler \
    pkg-config \
    libexpat-dev \
    libfl-dev \
    libboost-all-dev \
    default-jre

WORKDIR $tmpdir

run cd $tmpdir && git clone https://github.com/ucb-bar/rocket-chip.git
run cd rocket-chip && git checkout aca2f0c3b9fb81f42e4d1 && git submodule update --init riscv-tools && cd riscv-tools && git submodule update --init riscv-fesvr

RUN mkdir $tmpdir/rocket-chip/riscv
ENV RISCV=$tmpdir/rocket-chip/riscv
RUN cd $tmpdir/rocket-chip/riscv-tools/riscv-fesvr && mkdir build && cd build && ../configure --prefix=$RISCV --target=riscv64-unknown-elf && make install
RUN cd $tmpdir/rocket-chip && gdown https://drive.google.com/uc?id=1WnrYhhYTGUMpndvoNpnzJOjgxdTOBHyL && tar -xvf emulator.tar.gz
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:$tmpdir/rocket-chip/riscv/lib"

# Start your application
CMD ["/bin/bash"]
