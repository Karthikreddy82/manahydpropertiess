FROM nginxinc/nginx-unprivileged:alpine

WORKDIR /usr/share/nginx/html
RUN rm -rf ./*
COPY --chown=nginx:nginx . /usr/share/nginx/html/

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]