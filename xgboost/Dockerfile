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
COPY --chown=dcuser ./xgboost/train.py /home/dcuser/train.py
COPY --chown=dcuser ./xgboost/test-arg.py /home/dcuser/test-arg.py

# Switch to the dcuser user
USER dcuser
WORKDIR /home/dcuser

RUN wget https://mlphysics.ics.uci.edu/data/higgs/HIGGS.csv.gz

RUN pip install treelite
RUN pip install treelite-runtime
RUN pip install pandas
RUN pip install xgboost
RUN pip install scikit-learn

RUN python3 /home/dcuser/train.py
RUN unzip mymodel.zip
RUN cd /home/dcuser/libmymodel && make -j40

# Start your application
CMD ["/bin/bash"]
