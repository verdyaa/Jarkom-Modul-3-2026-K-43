#!/bin/bash

apt-get update -y && apt upgrade -y
apt-get install -y nginx

cat > /etc/nginx/sites-available/load-balancer.conf <<'NGINX'
upstream api_cluster {
    server 10.85.4.7:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 10.85.4.8:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 10.85.4.9:80 backup; # kirara
}

server {
    listen 80;
    server_name _;

    set_real_ip_from 10.85.1.4;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

ln -s /etc/nginx/sites-available/load-balancer.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
service nginx restart || service nginx start
