FROM docker.io/nginx:stable-perl
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
