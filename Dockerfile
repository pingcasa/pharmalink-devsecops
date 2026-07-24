FROM python:3.14-slim

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
