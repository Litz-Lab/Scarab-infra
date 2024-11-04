# syntax = edrevo/dockerfile-plus
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root

# Download Geekbench 6.3.0
RUN wget https://cdn.geekbench.com/Geekbench-6.3.0-Linux.tar.gz -O /tmp/Geekbench.tar.gz

# Extract the Geekbench archive
RUN tar -xvf /tmp/Geekbench.tar.gz -C /opt/ && \
    rm /tmp/Geekbench.tar.gz

# Exection of geekbench requires a license key, make sure the key is in the current dir
COPY ./geekbench6_license.key /opt/Geekbench-6.3.0-Linux

# Set the working directory to the Geekbench folder
WORKDIR /opt/Geekbench-6.3.0-Linux

# Ensure the Geekbench binary is executable
RUN chmod +x geekbench6

# Start your application
CMD ["/bin/bash"]