FROM nginx:1.27-alpine

# Serve upload.html as both /upload.html and the site root /
COPY upload.html /usr/share/nginx/html/upload.html
RUN cp /usr/share/nginx/html/upload.html /usr/share/nginx/html/index.html

# Generate runtime config.js from environment on container startup.
COPY config.template.js /usr/share/nginx/html/config.template.js
COPY docker-entrypoint.d/40-generate-config.sh /docker-entrypoint.d/40-generate-config.sh
RUN chmod +x /docker-entrypoint.d/40-generate-config.sh

EXPOSE 80
