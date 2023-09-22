# syntax = edrevo/dockerfile-plus
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y --no-install-recommends nano && rm -rf /var/lib/apt/lists/*;

INCLUDE+ ../common/Dockerfile.common
USER root

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends nginx openssl \
  && rm -rf /var/lib/apt/lists/*

# RUN apt-get update && apt-get install -y curl && curl -sSL https://get.docker.com/ | sh

# Increase the open file limit
COPY nginx/files/limits.conf.append /tmp/
RUN cat /tmp/limits.conf.append >> /etc/security/limits.conf

COPY nginx/files/nginx.location.append /tmp/
RUN cat /tmp/nginx.location.append > /etc/nginx/sites-available/default

COPY nginx/files/HTMLWebPlayer /usr/share/nginx/html/HTMLWebPlayer

# Update nginx to serve /videos
#RUN sed -i 's|/usr/share/nginx/html|/videos|g' /etc/nginx/sites-available/default

# ENTRYPOINT ["/etc/entrypoint.sh"]
WORKDIR /etc/nginx
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout media_streaming_CS_4.key -out media_streaming_CS_4.crt -subj '/C=CH/ST=VD/L=Lausanne/CN=www.mediaStreamingCS4.com'
WORKDIR /home/nginx

RUN sed -i "s/worker_connections \([0-9]*\);/worker_connections 2000;/g" /etc/nginx/nginx.conf
RUN sed -i "s/worker_processes auto;/worker_processes 1;/" /etc/nginx/nginx.conf

WORKDIR /home/memtrace
# RUN echo memtrace | sudo -S hostname a
RUN pip install pandas
RUN pip install scipy

# USER memtrace

RUN echo 'cd /home/memtrace/traces' > /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'rm -r `ls -t | awk "NR>1"`' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'cd dr*' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'mkdir -p bin' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'cp -f raw/modules.log bin/modules.log' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'cp -f raw/modules.log raw/modules.log.bak' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'echo "memtrace" | sudo -S python2 /home/memtrace/scarab/utils/memtrace/portabilize_trace.py .' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'cp -f bin/modules.log raw/modules.log' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo '/home/memtrace/dynamorio/package/build_release-64/clients/bin64/drraw2trace -indir ./raw/' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh
RUN echo 'cp -f /home/memtrace/scarab/src/PARAMS.sunny_cove /home/memtrace/exp/PARAMS.in' >> /home/memtrace/scarab/utils/memtrace/run_portabilize_trace.sh

RUN chmod +777 /home/memtrace/run_simpoint.sh

CMD ["/bin/bash"]
