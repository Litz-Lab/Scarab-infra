# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

WORKDIR $tmpdir

# TODO: Install required packages
RUN apt-get install -y make

# Start your application
CMD ["/bin/bash"]
