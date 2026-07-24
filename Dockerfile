FROM python:3.6-slim

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
