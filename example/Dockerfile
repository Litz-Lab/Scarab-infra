# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

WORKDIR $tmpdir

# TODO: Install required packages
RUN apt-get install -y make

RUN cd $tmpdir/scarab/utils/qsort && make test_qsort

WORKDIR /home/$username
# Start your application
CMD ["/bin/bash"]
