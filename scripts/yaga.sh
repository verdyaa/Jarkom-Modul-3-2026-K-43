#!/bin/bash

apt-get update -y && apt upgrade -y
apt-get install -y mariadb-server mariadb-client

mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql

cat << "EOF" > /etc/mysql/mariadb.conf.d/50-server.cnf
[server]
server-id = 1
log_bin   = /var/log/mysql/mariadb-bin.log
binlog_do_db    = db_shibuya_k43

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
