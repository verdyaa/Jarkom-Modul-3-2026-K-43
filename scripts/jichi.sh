#!/usr/bin/env bash

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 192.168.122.1" >> /etc/resolv.conf
apt update && apt -y upgrade && apt install isc-dhcp-relay vim -y

cat << "EOF" > /etc/default/isc-dhcp-relay
SERVERS="10.85.4.10"
INTERFACES="eth4 eth2 eth3"
OPTIONS=""
EOF

service isc-dhcp-relay restart

service isc-dhcp-relay status

