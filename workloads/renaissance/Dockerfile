# syntax = edrevo/dockerfile-plus

# Use focal (20.04) instead of latest (22.04) - rseq in DynamoRIO is dependent to glibc library and not working with too recent glibc in the 22.04 linux kernel
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# Should install python2 to run scarab/utils/memtrace/run_portabilize_trace.sh (cannot installed in Dockerfile.common because of ubuntu version
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python2

WORKDIR $tmpdir
# Install GraalVM (jvm)
RUN cd $tmpdir
RUN wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-22.3.1/graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
RUN tar -xzf graalvm-ce-java11-linux-amd64-22.3.1.tar.gz
ENV PATH=$tmpdir/graalvm-ce-java11-22.3.1/bin:$PATH
ENV JAVA_HOME=$tmpdir/graalvm-ce-java11-22.3.1
RUN wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.10.0/renaissance-gpl-0.10.0.jar

# Start your application
CMD ["/bin/bash"]
