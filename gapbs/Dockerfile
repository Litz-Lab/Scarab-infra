# syntax = edrevo/dockerfile-plus
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common
# TODO: Install required packages
USER root
# Switch to the dcuser user
USER dcuser
RUN git clone https://github.com/sbeamer/gapbs.git
RUN cd gapbs && make
# Start your application
CMD ["/bin/bash"]