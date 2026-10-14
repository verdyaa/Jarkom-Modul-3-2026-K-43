#!/bin/bash
apt update && apt -y upgrade && apt-get install bind9 -y
ln -s /etc/init.d/named /etc/init.d/bind9

mkdir /etc/bind/jarkom

cat << "EOF" > /etc/bind/named.conf.local
zone "k-43.com" {
  type slave;
  file "/etc/bind/k-43.com";
  masters { 10.85.1.2; };
};
EOF

cat << "EOF" >> /etc/bind/named.conf.local
zone "1.85.10.in-addr.arpa" {
    type slave;
    file "/etc/bind/1.85.10.in-addr.arpa";
    masters { 10.85.1.2; };
};
EOF

service bind9 restart

