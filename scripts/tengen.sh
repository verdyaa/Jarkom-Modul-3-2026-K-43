#!/usr/bin/bash
apt update && apt -y upgrade && apt install isc-dhcp-server vim -y

cat << "EOF" > /etc/default/isc-dhcp-server
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat << "EOF" > /etc/dhcp/dhcpd.conf
subnet 10.85.4.0 netmask 255.255.255.0 {
}

class "tim-dev" {
    match hardware;
}
subclass "tim-dev" 1:02:42:cb:61:6f:00; 
subclass "tim-dev" 1:02:42:ff:ac:1f:00; 

class "tim-support" {
    match hardware;
}
subclass "tim-support" 1:02:42:30:c4:89:00; # MAC zenin
subclass "tim-support" 1:02:42:ae:0a:eb:00; # MAC okkotsu

subnet 10.85.2.0 netmask 255.255.255.0 {
    option routers 10.85.2.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 10.85.2.255;
    option domain-name-servers 10.85.1.2, 10.85.1.3, 8.8.8.8, 192.168.122.1;

    default-lease-time 600;
    max-lease-time 3600;

    pool {
        allow members of "tim-dev";
        range 10.85.2.10 10.85.2.35;
    }

    pool {
        allow members of "tim-support";
        range 10.85.2.70 10.85.2.95;
    }
 }

class "short-lease" {
    match hardware;
}
subclass "short-lease" 1:02:42:dc:01:17:00; 
subclass "short-lease" 1:02:42:57:39:23:00; 

class "long-lease" {
    match hardware;
}
subclass "long-lease" 1:02:42:95:c7:f0:00; 

subnet 10.85.3.0 netmask 255.255.255.0 {
    option routers 10.85.3.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 10.85.3.255;

    option domain-name-servers 10.85.1.2, 10.85.1.3, 8.8.8.8, 192.168.122.1;
    option domain-name "k-43.com";
    
    pool {
        allow members of "short-lease";
        range 10.85.3.10 10.85.3.89;
        default-lease-time 1800;
        max-lease-time 1800;
    }

    # Pool Long Lease (12 Jam / 43200 detik)
    pool {
        allow members of "long-lease";
        range 10.85.3.100 10.85.3.199;
        default-lease-time 43200;
        max-lease-time 43200;
    }

    host kugisaki {
        hardware ethernet 02:42:c7:8d:46:00;
        fixed-address 10.85.3.99;
    }
}
EOF

dhcpd -t

service isc-dhcp-server restart
