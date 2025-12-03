#!/bin/bash

# We receive the domain name as an argument ($1)
DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Error: No domain name provided to certs.sh"
    exit 1
fi

echo "Executing External SSL Generation Script for $DOMAIN "

# 1. SYSTEM GENERATION
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"

# Ensure directories exist
mkdir -p $CERT_DIR
mkdir -p $KEY_DIR

# Generate the certificate
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 -keyout "$KEY_DIR/$DOMAIN.key" \
  -out "$CERT_DIR/$DOMAIN.crt" \
  -subj "/C=ES/ST=Andalucia/L=Granada/O=IES/CN=$DOMAIN" 2>/dev/null

# Permissions
chmod 600 "$KEY_DIR/$DOMAIN.key"
chmod 644 "$CERT_DIR/$DOMAIN.crt"

echo "Certificates created at system paths:"
echo " - Key: $KEY_DIR/$DOMAIN.key"
echo " - Crt: $CERT_DIR/$DOMAIN.crt"

# 2. MOVE TO DOCKER FOLDER
echo "Moving certificates to Project Docker folder"

# Define the local folder for your project
LOCAL_DIR="./config/certs"

# Create folder just in case
mkdir -p "$LOCAL_DIR"

# Copy the CRT and KEY renaming them to server.crt/key for Nginx
cp "$CERT_DIR/$DOMAIN.crt" "$LOCAL_DIR/server.crt"
cp "$KEY_DIR/$DOMAIN.key" "$LOCAL_DIR/server.key"

# Detect the real user 
REAL_USER=${SUDO_USER:-$USER}

# Give you ownership of the files
chown "$REAL_USER:$REAL_USER" "$LOCAL_DIR/server.crt"
chown "$REAL_USER:$REAL_USER" "$LOCAL_DIR/server.key"

echo "Certificates ready in $LOCAL_DIR"
