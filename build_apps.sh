LOCAL_UID=$(id -u $USER)
LOCAL_GID=$(id -g $USER)
USER_ID=${LOCAL_UID:-9001}
GROUP_ID=${LOCAL_GID:-9001}

# build from the beginning and overwrite whatever image with the same name
if [ $BUILD == 2 ]; then
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
elif [ $BUILD == 1 ]; then # find the existing cache/image and start from there
  DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker build . -f ./$APP_GROUPNAME/Dockerfile -t $APP_GROUPNAME:latest --build-arg ssh_prv_key="$(cat ~/.ssh/id_rsa)"
fi

# create volume for the app group
#docker volume create $APP_GROUPNAME

# start container
case $APP_GROUPNAME in
  solr)
    # solr requires the host machine to download the data (14GB) from cloudsuite by first running "docker run --name web_search_dataset cloudsuite/web-search:dataset" once
    if [ $( docker ps -a -f name=web_search_dataset | wc -l ) -eq 2 ]; then
      echo "dataset exists"
    else
      echo "dataset does not exist, downloading"
      docker run --name web_search_dataset cloudsuite/web-search:dataset
    fi
    # must mount dataset volume for server and docker to start querying
    docker exec -it --privileged $APP_GROUPNAME /bin/bash -c "/usr/local/bin/entrypoint.sh"
    docker exec -it -d --privileged $APP_GROUPNAME /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
    docker run -dit --privileged --name $APP_GROUPNAME --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME
    docker exec --privileged $APP_GROUPNAME /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    ;;
  spec2017)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e PIN_ROOT=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux -e LD_LIBRARY_PATH=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib -e DYNAMORIO_HOME=/home/$USER/dynamorio/package/build_release-64 -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh"
    ;;
  sysbench)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e PIN_ROOT=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux -e LD_LIBRARY_PATH=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib -e DYNAMORIO_HOME=/home/$USER/dynamorio/package/build_release-64 -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh \"$APPNAME\""
    ;;
  allbench_traces)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e PIN_ROOT=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux -e LD_LIBRARY_PATH=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=/soe/hlitz/lab/traces,target=/simpoint_traces,readonly --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    ;;
  *)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e PIN_ROOT=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux -e LD_LIBRARY_PATH=/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/intel64/runtime/pincrt:/home/$USER/pin-3.15-98253-gb56e429b1-gcc-linux/extras/xed-intel64/lib -e DYNAMORIO_HOME=/home/$USER/dynamorio/package/build_release-64 -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    ;;
esac
