# build from the beginning and overwrite whatever image with the same name
if [ $BUILD == 2 ]; then
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
elif [ $BUILD == 1 ]; then # find the existing cache/image and start from there
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
fi

# create volume for the app group
#docker volume create $APP_GROUPNAME

# start container
case $APPNAME in
  solr)
    # solr requires the host machine to download the data (14GB) from cloudsuite by first running "docker run --name web_search_dataset cloudsuite/web-search:dataset" once
    if [ $( docker ps -a -f name=web_search_dataset | wc -l ) -eq 2 ]; then
      echo "dataset exists"
    else
      echo "dataset does not exist, downloading"
      docker run --name web_search_dataset cloudsuite/web-search:dataset
    fi
    # must mount dataset volume for server and docker to start querying
    docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "/entrypoint.sh"
    docker exec -it -d --privileged $APP_GROUPNAME /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
    ;;
  *)
    ;;
esac
docker run -dit --privileged --name $APP_GROUPNAME -v $APP_GROUPNAME:/home/dcuser $APP_GROUPNAME:latest /bin/bash
docker start $APP_GROUPNAME &
