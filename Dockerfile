# Use an unprivileged, non-root Alpine Nginx base image to minimize attack surface
FROM nginxinc/nginx-unprivileged:alpine

# Clean default web assets
RUN rm -rf /usr/share/nginx/html/*

# Copy website assets with non-root ownership
COPY --chown=nginx:nginx . /usr/share/nginx/html/

# Expose unprivileged port (ports <1024 require root)
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]