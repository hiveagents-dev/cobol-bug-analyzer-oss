#!/bin/sh
set -e

# Check if SSL certificate exists
SSL_CERT="/etc/letsencrypt/live/cobol-analyzer.hiveagents.dev/fullchain.pem"

if [ -f "$SSL_CERT" ]; then
    echo "SSL certificate found. Activating HTTPS configuration..."
    rm -f /etc/nginx/conf.d/http-only.conf
    cp /etc/nginx/conf.d/ssl.conf.template /etc/nginx/conf.d/default.conf
else
    echo "No SSL certificate found. Using HTTP-only configuration..."
    cp /etc/nginx/conf.d/http-only.conf /etc/nginx/conf.d/default.conf
fi

# Test nginx configuration
nginx -t

# Start nginx
exec nginx -g "daemon off;"
