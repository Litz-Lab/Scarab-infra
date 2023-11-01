# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# Copy spec2017
COPY ./spec2017/cpu2017-1_0_5.iso /home/dcuser/

USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gfortran \
    lsb-release \
    software-properties-common


# Switch to the dcuser user
WORKDIR /home/dcuser
USER dcuser

RUN echo "dcuser" | wget https://apt.llvm.org/llvm.sh
RUN chmod u+x llvm.sh
RUN echo "dcuser" | sudo -S ./llvm.sh 16

COPY ./spec2017/compile-538-clang.sh /home/dcuser
COPY ./spec2017/memtrace.cfg /home/dcuser
COPY ./spec2017/entrypoint.sh /home/dcuser

# Start your application
CMD ["/bin/bash"]
