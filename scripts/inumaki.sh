#!/bin/bash

apt-get update -y && apt upgrade -y
apt-get install -y mariadb-server mariadb-client

cat << "EOF" > /etc/mysql/mariadb.conf.d/50-server.cnf
[server]
server-id = 2

[mariadbd]
pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr
bind-address            = 0.0.0.0

expire_logs_days        = 10
[embedded]

[mariadbd]
[mariadb-11.8]
EOF

service mariadb start
service mariadb status
