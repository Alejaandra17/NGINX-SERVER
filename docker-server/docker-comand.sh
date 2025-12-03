#!/bin/bash

# 1. Define Variables
CONTAINER_NAME="nginx-docker-commands"
HOST_PORT="8080"
HTTPS_PORT="8443"

# 2. Generate SSL Certificates FIRST
echo "Generating Certificates"
sudo ./certs.sh server

# 3. Clean previous container if exists
docker rm -f $CONTAINER_NAME 2>/dev/null

# 4. Run the container
echo "Starting Nginx manually on ports $HOST_PORT (HTTP) and $HTTPS_PORT (HTTPS)..."

docker run -d \
  --name $CONTAINER_NAME \
  -p $HOST_PORT:80 \
  -p $HTTPS_PORT:443 \
  -v "$(pwd)/config/html":/usr/share/nginx/html \
  -v "$(pwd)/config/conf/nginx.conf":/etc/nginx/conf.d/default.conf \
  -v "$(pwd)/config/conf/.htpasswd":/etc/nginx/.htpasswd \
  -v "$(pwd)/config/certs":/etc/ssl/certs \
  nginx:latest

echo "Done."
echo " -> HTTP:  http://localhost:$HOST_PORT"
echo " -> HTTPS: https://localhost:$HTTPS_PORT"