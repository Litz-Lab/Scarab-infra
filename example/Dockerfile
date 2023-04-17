# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./scarab_memtrace/Dockerfile.common

# TODO: Install required packages


# Switch to the memtrace user
USER memtrace

# Start your application
CMD ["/bin/bash"]
