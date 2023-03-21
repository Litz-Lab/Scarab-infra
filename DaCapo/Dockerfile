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
RUN wget https://sourceforge.net/projects/dacapobench/files/evaluation/dacapo-evaluation-git%2B309e1fa-java8.jar
RUN echo '#!/bin/bash' >> run_DaCapo.sh
RUN echo 'echo "Input application name (cassandra, kafka, tomcat)"' >> run_DaCapo.sh
RUN echo 'read appname' >> run_DaCapo.sh
RUN echo 'java -jar $PWD/dacapo-evaluation-git+309e1fa-java8.jar $appname -n 10' >> run_DaCapo.sh
RUN chmod +x run_DaCapo.sh

# Start your application
CMD ["/bin/bash"]
