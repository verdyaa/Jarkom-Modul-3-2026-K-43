#!/bin/bash
apt update && apt -y upgrade && apt-get install bind9 -y

ln -s /etc/init.d/named /etc/init.d/bind9
mkdir /etc/bind/jarkom
cat << "EOF" > /etc/bind/named.conf.local
zone "k-43.com" {
  type master;
  file "/etc/bind/jarkom/k-43.com";
  allow-transfer { 10.85.1.3; };
  notify yes;
};

zone "1.85.10.in-addr.arpa" {
    type master;
    file "/etc/bind/jarkom/1.85.10.in-addr.arpa";
    allow-transfer { 10.85.1.3; };
    notify yes;
};
EOF

cat << "EOF" > /etc/bind/jarkom/k-43.com
$TTL    604800          ; Waktu cache default (detik)
@       IN      SOA     utahime.k-43.com. root.k-43.com. (
                        2026101300 ; Serial diperbarui untuk memicu sinkronisasi
                        604800     ; Refresh (1 minggu)
                        86400      ; Retry (1 hari)
                        2419200    ; Expire (4 minggu)
                        604800 )   ; Negative Cache TTL
;

@       IN      NS      utahime.k-43.com.
@       IN      NS      shoko.k-43.com.

utahime IN      A       10.85.1.2
shoko   IN      A       10.85.1.3

gojo    IN      A       10.85.1.4
     
jujutsu IN      A       10.85.1.4

www     IN      CNAME   jujutsu
EOF

cat << "EOF" > /etc/bind/jarkom/1.85.10.in-addr.arpa
$TTL    604800          ; Waktu cache default (detik)
@       IN      SOA     utahime.k-43.com. root.k-43.com. (
                        2026101300 ; Serial diperbarui untuk memicu sinkronisasi
                        604800     ; Refresh (1 minggu)
                        86400      ; Retry (1 hari)
                        2419200    ; Expire (4 minggu)
                        604800 )   ; Negative Cache TTL
;

@       IN      NS      utahime.k-43.com.
@       IN      NS      shoko.k-43.com.

4       IN      PTR     gojo.k-43.com.
EOF

cat << "EOF" > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    forwarders { 192.168.122.1; };
    dnssec-validation no;
    allow-query{any;};
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

service bind9 restart

