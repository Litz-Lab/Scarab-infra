# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./scarab_memtrace/Dockerfile.common

# Copy SPEC2017
COPY ./SPEC2017/cpu2017-1_0_5.iso /home/memtrace/
# USER root
# RUN mount -t iso9660 -o ro,exec,loop cpu2017-1_0_5.iso ./cpu2017

# Switch to the memtrace user
# USER memtrace


# Start your application
CMD ["/bin/bash"]
