#!/bin/bash

# We receive the domain name as an argument ($1)
DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Error: No domain name provided to certs.sh"
    exit 1
fi

echo "--- Executing External SSL Generation Script for $DOMAIN ---"

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

echo "Certificates created at:"
echo " - Key: $KEY_DIR/$DOMAIN.key"
echo " - Crt: $CERT_DIR/$DOMAIN.crt"

