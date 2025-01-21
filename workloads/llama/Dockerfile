# syntax = edrevo/dockerfile-plus
FROM ubuntu:focal
    
INCLUDE+ ./common/Dockerfile.common
    
# TODO: Install required packages
USER root
  ¦ make \
  ¦ pkg-config \
  ¦ libgflags-dev \
  ¦ libiberty-dev \
  ¦ liblz4-dev \
  ¦ liblzma-dev \
  ¦ libsnappy-dev \
  ¦ zlib1g-dev \
  ¦ libssl-dev \
  ¦ wget \
  ¦ python3
# Switch to the dcuser user
USER dcuser
RUN git clone https://github.com/facebookresearch/llama.git
WORKDIR /home/dcuser/llama2
# Install Python dependencies
RUN pip install -e .
# Start your application
CMD ["/bin/bash"]
