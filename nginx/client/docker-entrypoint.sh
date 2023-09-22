#!/bin/bash
set -e

# $1: the IP of the server
# $2: the number of httperf clients
# $3: the total number of sessions
# $4: the rate (sessions per seconds)
# $5: plain text or encrypted communication, possible values are "PT" and "TLS"

if [ "$1" = "bash" ]; then
  exec $@
else
  until docker exec -it --privileged nginx /bin/bash -c 'service nginx status'; do 
    sleep 5
    echo -
  done
  echo starting client
  cd /root/run && ./benchmark.sh $1 $2 $3 $4 $5
  echo sending nginx quit cmd
  docker exec -dit --privileged nginx /bin/bash -c 'nginx -s quit'
fi
