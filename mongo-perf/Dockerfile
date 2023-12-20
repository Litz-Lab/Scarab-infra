# syntax = edrevo/dockerfile-plus

# choose a ubuntu version
FROM ubuntu:focal

INCLUDE+ ./common/Dockerfile.common

# TODO: Install required packages
USER root
RUN apt update && apt upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gnupg \
    curl \
    systemctl

RUN curl -fsSL https://pgp.mongodb.com/server-5.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-5.0.gpg \
   --dearmor
RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-5.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list

WORKDIR $tmpdir

RUN apt-get update
RUN apt-get install -y mongodb-org=5.0.20 mongodb-org-database=5.0.20 mongodb-org-server=5.0.20 mongodb-org-shell=5.0.20 mongodb-org-mongos=5.0.20 mongodb-org-tools=5.0.20
RUN chmod 777 /var/lib/mongodb

RUN git clone https://github.com/mongodb/mongo-perf.git
RUN pip install -r ./mongo-perf/requirements.txt
RUN cd mongo-perf && git reset --hard 11aaf7c
# overwrite the script due to the relative path
COPY mongo-perf/benchrun.py $tmpdir/mongo-perf

# Start your application
CMD ["/bin/bash"]
