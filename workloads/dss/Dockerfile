# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

#scarab & dynamorio
INCLUDE+ ./common/Dockerfile.common
WORKDIR $tmpdir

#reqs
USER root
#RUN apt-get install --no-install-recommends -y ca-certificates
#RUN apt-get install --no-install-recommends -y wget
#RUN apt-get install --no-install-recommends -y perl
#RUN apt-get install --no-install-recommends -y g++
#RUN apt-get install --no-install-recommends -y make
RUN apt-get install --no-install-recommends -y patch
RUN useradd -MUr qtss

#get source
WORKDIR $tmpdir
RUN wget https://github.com/macosforge/dss/archive/refs/tags/6.0.3.tar.gz
RUN tar -xzf 6.0.3.tar.gz
WORKDIR $tmpdir/dss-6.0.3

#patches to make dss compatable with 64-bit ubuntu linux by github:mdavid
RUN wget https://github.com/mdavid/DarwinStreamingServer-Linux/raw/master/DSS-6.0.3-linux.patch
RUN wget https://github.com/mdavid/DarwinStreamingServer-Linux/raw/master/DSS-6.0.3-x86_64.patch
RUN patch -p1 <DSS-6.0.3-linux.patch
RUN patch -p1 <DSS-6.0.3-x86_64.patch
#use c standard c++98
RUN sed -i 's/\(COMPILER_FLAGS="\)\(-D_REENTRANT -D__USE_POSIX -D__linux__ -pipe"\)$/\1-std=c++98 \2/g' Buildit
#update getopt definition
RUN sed -i 's/\(int getopt.*\);$/\1 throw();/g' CommonUtilitiesLib/getopt.h
#change ordering of linked libraries
RUN sed -i 's/^\(LIBS \=\)\(\ $(CORE_LINK_LIBS)\)\( .*\)$/\1\3\2/g' QTFileTools/*/Makefile.POSIX Makefile.POSIX

#build and install
RUN ./Buildit install
WORKDIR $tmpdir/dss-6.0.3/DarwinStreamingSrvr-Linux
RUN sed -i 's/^\(eval "use Net::SSLeay";\)/if ($^O eq "linux")\n{\n\tpush(@INC, "\/var\/streaming\/AdminHtml");\n}\n\1/1' streamingadminserver.pl
#Darwin Streaming Server 6.0.3 7,500 clients, 60GB dataset, high bitratez
RUN sed -i 's/^concurrentclients.*$/concurrentclients\t1/1' streamingloadtool.conf
#TODO: 1->7,500 clients, 60GB dataset, high bitratez
RUN sed -i 's/^url.*$/url rtsp:\/\/127.0.0.1:7070\/sample_100kbit.mov/1' streamingloadtool.conf
#RUN sed -i 's/\(kill_clients_when_broadcast_stops".*\)false/\1true/1' dss-6.0.3/DarwinStreamingSrvr-Linux/streamingserver.xml
RUN sed -i 's/\(maximum_connections.*\)1000/\17500/1' streamingserver.xml
RUN sed -i 's/^runforever.*$/runforever\tno/1' streamingloadtool.conf
RUN (echo a; echo a; echo a) | ./Install
RUN cp /usr/local/movies/sample_100kbit.mov /usr/local/movies/streamingloadtool.mov

#run admin: streamingadminserver.pl
#run server: DarwinStreamingServer
#testing: StreamingLoadTool -f /etc/streaming/streamingloadtool.conf

CMD ["/bin/bash"]

