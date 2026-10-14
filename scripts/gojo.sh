#!/bin/bash

apt-get update -y && apt upgrade -y
apt-get install -y nginx

mkdir -p /var/cache/nginx

cat > /etc/nginx/sites-available/gojo-router.conf <<'NGINX'
# Upstream untuk Web Worker (Round Robin adalah default)
upstream web_cluster {
    server 10.85.4.5:80;  # <-- Ganti dengan IP Maki (misal: 10.85.4.5)
    server 10.85.4.6:80; # <-- Ganti dengan IP Panda (misal: 10.85.4.6)
}

proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m inactive=60m;

limit_req_zone $binary_remote_addr zone=limit_api:10m rate=10r/s;

server {
    listen 80;
    
    server_name jujutsu.k-43.com www.jujutsu.k-43.com;

    location / {
        proxy_pass http://web_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_cache my_cache;
        proxy_cache_valid 200 302 10m;  # Simpan cache status HTTP 200 & 302 selama 10 menit
        proxy_cache_valid 404 1m;       # Simpan cache status 404 selama 1 menit

        add_header X-Cache-Status $upstream_cache_status;
    }

    location /api/ {
        proxy_pass http://10.85.4.4/; # <-- Ganti dengan IP Geto
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        limit_req zone=limit_api;
        limit_req_status 503; # Mengembalikan HTTP 503 saat request melebihi batas (default)

    }
}
NGINX

ln -s /etc/nginx/sites-available/gojo-router.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
service nginx restart || service nginx start
