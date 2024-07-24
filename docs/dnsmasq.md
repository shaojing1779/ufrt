# DNSMASQ

## NOTICE

FreeBSD conf file:  
/usr/local/etc/dnsmasq.conf  
/usr/local/etc/dnsmasq.d  

Linux conf file:  
/etc/dnsmasq.conf  
/etc/dnsmasq.d  

## CONFIGURE

/etc/dnsmasq.conf

```ini
# Configuration file for dnsmasq.
listen-address=127.0.0.1,10.11.0.254
dhcp-range=interface:vtnet1,10.11.0.100,10.11.0.200,48h
resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
# log-queries
log-facility=/var/log/dnsmasq/dnsmasq.log
log-async=100
conf-dir=/etc/dnsmasq.d
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

## adblock-for-dnsmasq

[/etc/dnsmasq.d/adblock-for-dnsmasq.conf](https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/adblock-for-dnsmasq.conf)
[github.com/privacy-protection-tools/anti-AD.git](https://github.com/privacy-protection-tools/anti-AD.git)

```sh
wget https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/adblock-for-dnsmasq.conf -O /etc/dnsmasq.d/adblock-for-dnsmasq.conf
```

## GFWList

```bash
wget https://raw.githubusercontent.com/cokebar/gfwlist2dnsmasq/master/gfwlist2dnsmasq.sh
chmod +x gfwlist2dnsmasq.sh
sudo sh -c './gfwlist2dnsmasq.sh -o /etc/dnsmasq.d/dnsmasq_gfwlist.conf'
```

## PUBLIC DNS SERVER

```sh
Google:
8.8.8.8
8.8.4.4

Cloudflare:
1.1.1.1
1.0.0.1

Microsoft:
4.2.2.1
4.2.2.2
```
