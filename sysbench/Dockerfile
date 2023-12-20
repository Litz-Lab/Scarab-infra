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
    libpq-dev \
    mysql-server \
    postgresql

RUN chmod -R 755 /var/run/mysqld

WORKDIR $tmpdir
RUN cd $tmpdir && git clone https://github.com/akopytov/sysbench.git
COPY ./sysbench/entrypoint.sh $tmpdir

# Start your application
CMD ["/bin/bash"]
