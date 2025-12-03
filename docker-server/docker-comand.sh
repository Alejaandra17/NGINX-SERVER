#!/bin/bash

# 1. Define Variables
CONTAINER_NAME="nginx-docker-commands"
HOST_PORT="8080"

# 2. Run the container
echo "Starting Nginx manually on port $HOST_PORT..."

docker run -d \
  --name $CONTAINER_NAME \
  -p $HOST_PORT:80 \
  -v "$(pwd)/html":/usr/share/nginx/html \
  -v "$(pwd)/conf/nginx.conf":/etc/nginx/conf.d/default.conf \
  -v "$(pwd)/config/conf/.htpasswd":/etc/nginx/.htpasswd \
  nginx:latest

echo "Done. Access at http://localhost:$HOST_PORT"