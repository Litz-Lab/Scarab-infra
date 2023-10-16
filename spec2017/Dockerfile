# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# Copy SPEC2017
COPY ./SPEC2017/cpu2017-1_0_5.iso /home/dcuser/

USER root
RUN apt-get install -y gfortran
# RUN mount -t iso9660 -o ro,exec,loop cpu2017-1_0_5.iso ./cpu2017

# Switch to the dcuser user
USER dcuser

RUN cd /home/dcuser && mkdir cpu2017_install && echo "memtrace" | sudo -S mount -t iso9660 -o ro,exec,loop cpu2017-1_0_5.iso ./cpu2017_install
RUN cd /home/dcuser && mkdir cpu2017 && cd cpu2017_install && echo "yes" | ./install.sh -d /home/dcuser/cpu2017

COPY ./SPEC2017/memtrace.cfg /home/dcuser/cpu2017/config/

# Start your application
CMD ["/bin/bash"]
