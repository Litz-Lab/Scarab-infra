FROM cloudsuite/media-streaming:client

RUN apt-get update && apt-get install -y curl && curl -sSL https://get.docker.com/ | sh

COPY nginx/client/docker-entrypoint.sh /root/docker-entrypoint.sh

RUN chmod +777 /root/docker-entrypoint.sh
RUN chmod -R +777 /root/run
RUN chmod -R +777 /root/videoperf