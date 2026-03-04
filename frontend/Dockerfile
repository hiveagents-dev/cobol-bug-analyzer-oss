# Frontend Dockerfile for COBOL Bug Analyzer
FROM nginx:alpine

# Install certbot for Let's Encrypt SSL
RUN apk add --no-cache certbot certbot-nginx

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configurations
# Start with HTTP-only config, then switch to SSL after certificate generation
COPY nginx.conf /etc/nginx/conf.d/http-only.conf
COPY nginx-ssl.conf /etc/nginx/conf.d/ssl.conf.template

# Copy frontend files to nginx serve directory
COPY src/ /usr/share/nginx/html/

# Create Let's Encrypt challenge directory
RUN mkdir -p /usr/share/nginx/html/.well-known/acme-challenge && \
    chmod -R 755 /usr/share/nginx/html/.well-known

# Copy custom entrypoint that auto-detects SSL certificate
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose ports 80 and 443
EXPOSE 80 443

# Use custom entrypoint that activates SSL if certificate exists
ENTRYPOINT ["/docker-entrypoint.sh"]
