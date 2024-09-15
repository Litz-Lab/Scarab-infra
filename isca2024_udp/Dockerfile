# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root
RUN pip install gdown
WORKDIR /simpoint_traces

RUN gdown https://drive.google.com/uc?id=1tfKL7wYK1mUqpCH8yPaPVvxk2UIAJrOX && tar -xzvf simpoint_traces.tar.gz
COPY ./isca2024_udp/entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR $tmpdir
COPY ./isca2024_udp/plot $tmpdir/plot
COPY ./isca2024_udp/isca.json $tmpdir/isca.json
COPY ./isca2024_udp/isca.pt.json $tmpdir/isca.pt.json

# Start your application
CMD ["/bin/bash"]
