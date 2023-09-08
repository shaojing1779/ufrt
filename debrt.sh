#!/bin/bash

# interface name
IFACE_LAN=eno1
IFACE_WAN=enp1s0

# ip address
ADDR_LAN=10.21.0.254
ADDR_WAN=192.168.31.1

DHCP_BEG=10.21.0.50
DHCP_END=10.21.0.200

# dns server
DNS1=114.114.114.114
DNS2=8.8.8.8

# default gateway
GATEWAY=192.168.31.254

# create deploy directory
DEP_DIR=/opt/debrt; mkdir -p $DEP_DIR

# install packages
function install_pkg {
	apt install -y tcpdump bridge-utils iptraf iftop openssl
	apt install -y unzip vim-tiny tree wget curl
	apt isntall -y nfs-common samba dsnmasq
}

# network setting
function network_set {
	# ip address setting
	echo 'source /etc/network/interfaces.d/*' > /etc/network/interfaces

	echo "# The loopback network interface
	auto lo
	iface lo inet loopback
	# The LAN network interface
	auto ${IFACE_LAN}
	iface ${IFACE_LAN} inet static
			address ${ADDR_LAN}/24
	# The WAN network interface
	auto ${IFACE_WAN}
	iface ${IFACE_WAN} inet static
			address ${ADDR_WAN}/24
			gateway ${GATEWAY}
			dns-nameservers $DNS1 $DNS2" > /etc/network/interfaces.d/static.iface

	# add static route
	echo "#!/bin/sh
	if [ \"$IFACE\" = ${IFACE_LAN} ]; then
		# ip route add 192.168.1.0/24 via 192.168.31.254
	fi" > /etc/network/if-up.d/route
}

# iptables setting
function iptables_set {
	# ip_forward
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
	echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p

	# LAN interface
	iptables -t nat -A POSTROUTING -o ${IFACE_WAN} -j MASQUERADE

	# iptables save
	apt install -y iptables-persistent
}

# dnsmasq setting
function dnsmasq_set {
	# dnsmasq dhcp
	echo "listen-address=${ADDR_LAN},127.0.0.1

	dhcp-range=${DHCP_BEG},${DHCP_END},48h
	resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
	log-facility=/var/log/dnsmasq/dnsmasq.log
	log-async=100

	conf-dir=/etc/dnsmasq.d" > /etc/dnsmasq.conf

	# dnsmasq address
	echo "address=/me.games.play/${ADDR_LAN}"
	>> /etc/dnsmasq.d/address.conf

	# dnsmasq resolv
	echo "all-servers
	server=/cn/114.114.114.114
	server=192.168.31.254
	server=223.5.5.5
	server=/google.com/8.8.8.8" > /etc/dnsmasq.d/resolv.dnsmasq.conf
}

# start server
function start_server {
	sudo systemctl enable --now sambd
	sudo systemctl enable --now rpcbind
	sudo systemctl enable --now sshd
	sudo systemctl enable --now dnsmasq
}

function main {
	# network setting
	network_set;
	# iptables setting
	iptables_set;
	# dnsmasq setting
	dnsmasq_set;
	# start server
	start_server;

	# restart system
	reboot;
}
