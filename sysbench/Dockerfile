# syntax = edrevo/dockerfile-plus

FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# TODO: Install required packages
USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    make \
    automake \
    libtool \
    pkg-config \
    libaio-dev \
    libmysqlclient-dev \
    libssl-dev \
    libpq-dev

# Switch to the dcuser user
USER dcuser
RUN git clone https://github.com/akopytov/sysbench.git
RUN cd sysbench && ./autogen.sh && ./configure && make -j && echo "dcuer" | sudo -S make install

# Start your application
CMD ["/bin/bash"]
