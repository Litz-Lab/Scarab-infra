#syntax = edrevo/dockerfile-plus
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root
# Switch to the dcuser user
USER dcuser

ADD /geekbench/Geekbench-6.2.2-Linux.tar.gz .

# Start your application
CMD ["/bin/bash"]