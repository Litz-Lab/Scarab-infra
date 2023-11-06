# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# TODO: Install required packages
RUN apt-get install -y make

RUN cd /home/dcuser/scarab/utils/qsort && make test_qsort

# Switch to the dcuser user
USER dcuser

# Start your application
CMD ["/bin/bash"]
