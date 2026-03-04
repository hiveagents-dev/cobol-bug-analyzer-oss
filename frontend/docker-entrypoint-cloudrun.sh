#!/bin/sh
set -e

# Cloud Run entrypoint - uses envsubst to inject BACKEND_URL
echo "Configuring nginx for Cloud Run..."
echo "BACKEND_URL: ${BACKEND_URL:-not set}"

# Default backend URL if not set
export BACKEND_URL="${BACKEND_URL:-http://localhost:5000}"

# Use envsubst to replace environment variables in nginx config
envsubst '${BACKEND_URL}' < /etc/nginx/conf.d/cloudrun.conf.template > /etc/nginx/conf.d/default.conf

# Test nginx configuration
nginx -t

echo "Starting nginx..."
# Start nginx
exec nginx -g "daemon off;"
