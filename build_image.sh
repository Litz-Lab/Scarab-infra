#!/bin/bash

# code to ignore case restrictions
shopt -s nocasematch

echo "Input application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress)"
read appname
echo "Input image name and tag (e.g. cassandra:latest)"
read imagename

# case statement
case $appname in
  cassandra | kafka | tomcat)
    echo "DaCapo applications"
    docker build . -f ./DaCapo/Dockerfile --no-cache -t $imagename
     ;;
  chirper | http)
    echo "Renaissance applications"
    docker build . -f ./Renaissance/Dockerfile --no-cache -t $imagename
     ;;
  drupal7 | mediawiki | wordpress)
    echo "HHVM OSS-performance applications"
    docker build . -f ./OSS/Dockerfile --no-cache -t $imagename
     ;;
  *)
    echo "unknown"
    ;;
esac


# Sample command
# docker build . -f ./$appname/Dockerfile --no-cache -t $imagename
