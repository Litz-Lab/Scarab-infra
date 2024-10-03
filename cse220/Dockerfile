# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

USER root
RUN pip install gdown
WORKDIR /

RUN gdown https://drive.google.com/uc?id=1Z4ouWgNrkNnezrq7wxk4OXBpRBm-2CzA && tar -xzvf cse220_traces.tar.gz
COPY ./cse220/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./cse220/run_cse220.sh /usr/local/bin/run_cse220.sh
COPY ./cse220/run_exp_using_descriptor.py /usr/local/bin/run_exp_using_descriptor.py

WORKDIR $tmpdir
COPY ./cse220/plot $tmpdir/plot
COPY ./cse220/lab1.json $tmpdir/lab1.json

# Start your application
CMD ["/bin/bash"]
