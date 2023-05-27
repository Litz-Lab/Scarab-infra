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

# Switch to the memtrace user
USER memtrace

RUN git clone https://github.com/ucb-bar/rocket-chip.git
RUN cd rocket-chip && git submodule update --init

RUN mkdir riscv
ENV RISCV=/home/memtrace/rocket-chip/riscv
RUN git clone https://github.com/freechipsproject/rocket-tools
RUN cd rocket-tools && git submodule update --init --recursive
ENV MAKEFLAGS="$MAKEFLAGS -j40"
RUN cd rocket-tools && ./build.sh

RUN cd /home/memtrace/rocket-chip/emulator && make
