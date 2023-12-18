# syntax = edrevo/dockerfile-plus

# Use bionic (18.04) instead of latest (22.04) - hhvm 3.30 is the latest version supporting PHP run. hhvm 3.30 is not available in later version of ubuntu
FROM ubuntu:18.04
# Ubuntu 14:04 with HHVM installed
#FROM hhvm/hhvm

INCLUDE+ ./common/Dockerfile.oss

USER root
# Should install python2 to run scarab/utils/memtrace/run_portabilize_trace.sh (cannot installed in Dockerfile.common because of ubuntu version
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python-minimal

# Install HHVM requirements
WORKDIR $tmpdir
RUN cd $tmpdir && wget -c https://ftp.gnu.org/gnu/glibc/glibc-2.29.tar.gz && tar -zxvf glibc-2.29.tar.gz && cd glibc-2.29 && mkdir glibc-build && cd glibc-build && ../configure --prefix=/opt/glibc && make && make install
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common apt-transport-https
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xB4112585D386EB94
#RUN apt-add-repository "deb https://dl.hhvm.com/$(lsb_release --id --short | tr '[:upper:]' '[:lower:]') $(lsb_release --codename --short)-lts-3.24 main"
ENV TZ=US/Pacific
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN add-apt-repository -s https://dl.hhvm.com/ubuntu && apt-get update && apt-get build-dep -y hhvm-nightly
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y hhvm

# Install HHVM
RUN git clone https://github.com/facebook/hhvm.git
RUN cd hhvm && git submodule update --init --recursive

# Building HHVM
#RUN mkdir -p $tmpdir/hhvm/build && cd $tmpdir/hhvm/build && cmake -DMYSQL_UNIX_SOCK_ADDR=/var/run/mysqld/mysqld.sock .. && make -j 40 && sudo make install

# Install oss-performance
RUN cd $tmpdir && git clone https://github.com/facebookarchive/oss-performance.git
# update setup script
COPY ./OSS/setup.sh $tmpdir/oss-performance/scripts
#RUN bash $tmpdir/oss-performance/scripts/setup.sh

WORKDIR /home/$username
USER $username
# Start your application
CMD ["/bin/bash"]
