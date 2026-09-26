# Use an unprivileged, non-root Alpine Nginx base image
FROM nginxinc/nginx-unprivileged:alpine

# Copy website assets directly to the Nginx document root
COPY --chown=nginx:nginx . /usr/share/nginx/html/

# Expose unprivileged port
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]