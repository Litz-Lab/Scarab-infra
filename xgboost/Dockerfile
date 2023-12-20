# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:20.04

INCLUDE+ ./common/Dockerfile.common

# TODO: Install required packages
USER root
RUN apt update && apt upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    unzip
COPY ./xgboost/train.py $tmpdir/train.py
COPY ./xgboost/test-arg.py $tmpdir/test-arg.py

WORKDIR $tmpdir

RUN wget https://mlphysics.ics.uci.edu/data/higgs/HIGGS.csv.gz

RUN pip install treelite
RUN pip install treelite-runtime
RUN pip install pandas
RUN pip install xgboost
RUN pip install scikit-learn

RUN python3 $tmpdir/train.py
RUN unzip mymodel.zip
RUN cd $tmpdir/libmymodel && make -j40

# Start your application
CMD ["/bin/bash"]
