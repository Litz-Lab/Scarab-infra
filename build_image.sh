#!/bin/bash

echo "Input application name (cassandra, kafka, tomcat, chirper, http, drupal7, mediawiki, wordpress)"
read appname
echo "Input image name and tag (e.g. cassandra:latest)"
read imagename

docker build . -f ./$appname/Dockerfile --no-cache -t $imagename
