FROM cloudsuite/base-os:ubuntu

RUN apt-get update && apt-get install -y curl && curl -sSL https://get.docker.com/ | sh

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bc \
    build-essential \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY nginx/client/files /root/
RUN set -x \
    && mkdir -p /root/build \
    && cd /root/build \
    && chmod +777 /root/videoperf/configure \
    && /root/videoperf/configure \
    && make \
    && chmod +777 /root/videoperf/mkinstalldirs \
    && make install

RUN chmod +777 /root/docker-entrypoint.sh
RUN chmod -R +777 /root/run
RUN chmod -R +777 /root/videoperf

RUN rm -rf /output && mkdir -p /output
VOLUME ["/output"]

RUN rm -rf /videos/logs && mkdir -p /videos/logs
VOLUME [ "/videos/logs" ]

ENTRYPOINT ["/root/docker-entrypoint.sh"]
# CMD /bin/bash