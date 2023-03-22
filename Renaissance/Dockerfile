# syntax = edrevo/dockerfile-plus

FROM ubuntu:latest

INCLUDE+ ./scarab_memtrace/Dockerfile.common

# Set the user to memtrace
USER memtrace

# Install GraalVM (jvm)
RUN cd /home/memtrace
RUN wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.1/graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
RUN tar -xzf graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
ENV PATH=/home/memtrace/graalvm-ce-java11-22.3.1/bin:$PATH
ENV JAVA_HOME=/home/memtrace/graalvm-ce-java11-22.3.1
RUN wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.10.0/renaissance-gpl-0.10.0.jar
RUN echo '#!/bin/bash' >> run_Renaissance.sh
RUN echo 'echo "Input application name (chirper http)"' >> run_Renaissance.sh
RUN echo 'read appname' >> run_Renaissance.sh
RUN echo 'java -jar $PWD/renaissance-gpl-0.10.0.jar finagle-$appname -r 10' >> run_Renaissance.sh
RUN chmod +x run_Renaissance.sh

# Start your application
CMD ["/bin/bash"]
