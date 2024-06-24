# DNSMASQ

/etc/dnsmasq.conf

```ini
# Configuration file for dnsmasq.
listen-address=127.0.0.1,10.11.0.254
dhcp-range=interface:vtnet1,10.11.0.100,10.11.0.200,48h
resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
# log-queries
log-facility=/var/log/dnsmasq/dnsmasq.log
log-async=100
conf-dir=/usr/local/etc/dnsmasq.d
```

/etc/dnsmasq.d/resolv.dnsmasq.conf

```ini
all-servers
server=10.21.0.1
server=114.114.114.114
server=/cn/114.114.114.114
```

/etc/dnsmasq.d/address.conf

```ini
address=/gw.example.net/10.11.0.254
address=/example.net/10.11.0.254
address=/www.example.net/10.11.0.254
```

/etc/dnsmasq.d/dhcp_static.conf

```ini
dhcp-host=asus-pc,a4:39:b3:43:b0:d1,10.11.0.201,infinite
```
