# syntax = edrevo/dockerfile-plus

INCLUDE+ ./scarab_memtrace/Dockerfile.common

# Install GraalVM (jvm)
RUN cd /home/memtrace
RUN wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.1/graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
RUN tar -xzf graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
ENV PATH=/home/memtrace/graalvm-ce-java11-22.3.1/bin:$PATH
ENV JAVA_HOME=/home/memtrace/graalvm-ce-java11-22.3.1
RUN wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.10.0/renaissance-gpl-0.10.0.jar

# Start your application
CMD ["/bin/bash"]
