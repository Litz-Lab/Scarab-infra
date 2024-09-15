# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root
RUN pip install gdown
WORKDIR /simpoint_traces

RUN gdown https://drive.google.com/uc?id=1tfKL7wYK1mUqpCH8yPaPVvxk2UIAJrOX && tar -xzvf simpoint_traces.tar.gz
COPY ./docker_traces/entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR $tmpdir
COPY ./docker_traces/desc.json $tmpdir/desc.json
COPY ./docker_traces/desc.pt.json $tmpdir/desc.pt.json

# Start your application
CMD ["/bin/bash"]
