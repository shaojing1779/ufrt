#!/bin/bash

# frpc to frps
FRP_PORT_SSH=9701
# deploy directory
DEP_DIR=/opt/debrt

# network setting
nmcli con add con-name eth0_static ifname eth0 \
    type ethernet autoconnect yes ipv4.method manual \
    ipv4.addresses 10.21.0.254/24
nmcli con add con-name eth1_static ifname eth1 \
    type ethernet autoconnect yes ipv4.method manual \
    ipv4.addresses 192.168.31.1/24 ipv4.gateway 192.168.31.254 ipv4.dns 127.0.0.1

# install packages
apt install tcpdump bridge-utils iptraf iftop network-manager openssl
apt unzip vim-tiny tree wget curl
apt nfs-common samba dsnmasq

# create work directory & soft
mkdir -p $DEP_DIR && cd /opt/debtr
if [ $? != 0 ]
then
    echo "[mkdir $DEP_DIR] error!"
    exit;
fi
# frp
wget https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz
tar zxvf frp_0.51.3_linux_amd64.tar.gz -C $DEP_DIR

ln -s frp_0.51.3_linux_amd64 frp

echo "[common]
server_addr = frps.coolbit.work
server_port = 7112
token = sam&frodo

[nuc_ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = $FRP_PORT_SSH" > $DEP_DIR/frp/frpc.ini

echo '[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=$DEP_DIR/frp/frpc -c $DEP_DIR/frp/frpc.ini

[Install]
WantedBy=multi-user.target' > /usr/lib/systemd/system/frpc.service

# v2ray
wget https://github.com/v2fly/v2ray-core/releases/download/v4.31.0/v2ray-linux-64.zip
unzip v2ray-linux-64.zip -d $DEP_DIR/v2ray

echo '{
  "inbounds": [
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "udp": true,
        "auto": "noauth",
        "ip": "0.0.0.0"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "coolbit.work",
            "port": 993,
            "users": [
              {
                "id": "efdcbfcc-3456-42b5-8166-cf7528605008"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false,
          "serverName": "coolbit.work"
        },
        "tcpSettings": null,
        "kcpSettings": null,
        "wsSettings": {
          "connectionReuse": true,
          "path": "/index",
          "headers": {
            "Host": "coolbit.work"
          }
        },
        "httpSettings": null,
        "quicSettings": null
      }
    },
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "coolbit.work",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}' > $DEP_DIR/v2ray/config.json

echo '[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$DEP_DIR/v2ray/bin/v2ray -config $DEP_DIR/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target' > /usr/lib/systemd/system/v2ray.service

# ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p
iptables -t nat -A POSTROUTING -o enp8s0 -j MASQUERADE

# dnsmasq
echo 'listen-address=10.43.0.254,127.0.0.1
dhcp-range=10.43.0.50,10.43.0.150,48h
resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
log-facility=/var/log/dnsmasq/dnsmasq.log
log-async=100
conf-dir=/etc/dnsmasq.d' > /etc/dnsmasq.conf

echo 'all-servers
server=202.106.0.20
server=192.168.31.254
server=114.114.114.114
server=8.8.8.8
server=168.95.1.1

address=/nas.coolbit.work/192.168.31.95
address=/nas/192.168.31.95
address=/nuc.coolbit.work/192.168.31.198
address=/nuc/192.168.31.198' > /etc/dnsmasq.d/resolv.dnsmasq.conf


# start server
sudo systemctl enable --now sambd
sudo systemctl enable --now rpcbind
sudo systemctl enable --now sshd
sudo systemctl enable --now dnsmasq
sudo systemctl enable --now frpc
sudo systemctl enable --now v2ray
