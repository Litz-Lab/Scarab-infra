# syntax = edrevo/dockerfile-plus
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root

RUN wget https://cdn.geekbench.com/Geekbench-6.2.2-Linux.tar.gz
RUN tar xf Geekbench-6.2.2-Linux.tar.gz

# Start your application
CMD ["/bin/bash"]