LOCAL_UID=$(id -u $USER)
LOCAL_GID=$(id -g $USER)
USER_ID=${LOCAL_UID:-9001}
GROUP_ID=${LOCAL_GID:-9001}

# build from the beginning and overwrite whatever image with the same name
if [ $BUILD == 2 ]; then
  docker build . -f ./$APP_GROUPNAME/Dockerfile --no-cache -t $APP_GROUPNAME:latest
elif [ $BUILD == 1 ]; then # find the existing cache/image and start from there
  docker build . -f ./$APP_GROUPNAME/Dockerfile -t $APP_GROUPNAME:latest
fi

# create volume for the app group
#docker volume create $APP_GROUPNAME

mkdir -p $OUTDIR/.ssh
cp ~/.ssh/id_rsa $OUTDIR/.ssh/id_rsa
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
    docker exec -it --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh"
    docker exec -it -d --privileged $APP_GROUPNAME\_$USER /bin/bash -c '(docker run -it --name web_search_client --net host cloudsuite/web-search:client $(hostname -I) 10; pkill java)'
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
  spec2017)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "\$tmpdir/entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "\$tmpdir/install.sh"
    ;;
  sysbench)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh \"$APPNAME\""
    ;;
  allbench_traces)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=/soe/hlitz/lab/traces,target=/simpoint_traces,readonly --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
  isca2024_udp)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
  cse220)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
  docker_traces)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
  example)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/utils/qsort && make test_qsort"
    ;;
  *)
    docker run -e user_id=$USER_ID -e group_id=$GROUP_ID -e username=$USER -e HOME=/home/$USER -dit --privileged --name $APP_GROUPNAME\_$USER --mount type=bind,source=$OUTDIR,target=/home/$USER $APP_GROUPNAME:latest /bin/bash
    docker start $APP_GROUPNAME\_$USER
    docker exec --privileged $APP_GROUPNAME\_$USER /bin/bash -c "/usr/local/bin/common_entrypoint.sh"
    docker exec --user=$USER --privileged $APP_GROUPNAME\_$USER /bin/bash -c "cd /home/$USER/scarab/src && make clean && make"
    ;;
esac

# Build scarab
