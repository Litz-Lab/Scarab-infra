# syntax = edrevo/dockerfile-plus
FROM ubuntu:20.04

INCLUDE+ ./common/Dockerfile.tailbench

WORKDIR $tmpdir
USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y uuid-dev

RUN wget http://tailbench.csail.mit.edu/tailbench-v0.9.tgz
RUN wget http://tailbench.csail.mit.edu/tailbench.inputs.tgz
RUN tar xf tailbench-v0.9.tgz
RUN tar xf tailbench.inputs.tgz
RUN cd tailbench-v0.9 && ./build.sh xapian

# Start your application
CMD ["/bin/bash"]
