# syntax = edrevo/dockerfile-plus
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# TODO: Install required packages
USER root
# Switch to the dcuser user
USER dcuser
RUN git clone https://github.com/facebook/rocksdb.git
RUN cd rocksdb && make

# start your application
CMD ["/bin/bash"]