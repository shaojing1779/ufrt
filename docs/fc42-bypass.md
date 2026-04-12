# Fedora42 Router

## Summary

Fedora42 作为路由器

### 网络工具

```bash
sudo dnf install dnsmasq nfs-utils net-tools tcpdump bridge-utils iptraf iftop openssl unzip vim tree wget curl munin nginx

```

### 网络接口管理

```bash
# 使用networking服务管理网络接口 如使用NetwokManager管理网络请参考其文档

```


### 开启路由转发

```bash
# /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf && sysctl -p
```

### 内核参数优化

```bash
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
```

## DNSmasq设置(主DHCP)

`/etc/dnsmasq.d/dhcpd.conf`  

```ini
# gateway
dhcp-option=option:router,10.20.0.1
# bypass
dhcp-option=tag:bypass,option:router,10.20.0.3
## hp
dhcp-host=3c:52:82:01:fd:3f,set:bypass
dhcp-host=hp,00:01:20:19:09:73,10.20.0.11,infinite,set:bypass
```

## v2ray透明代理

`/usr/local/v2ray/config.json`  

```json
{
    "log": {
      "loglevel": "error",
      "access": "/var/log/v2ray/access.log",
      "error": "/var/log/v2ray/error.log"
    },
    "inbounds": [{
        "tag":"transparent",
        "port":3316,
        "protocol":"dokodemo-door",
        "settings":{
            "network":"tcp,udp",
            "followRedirect":true
        },
        "sniffing":{
            "enabled":true,
            "destOverride":[
                "http",
                "tls"
            ]
        },
        "streamSettings":{
            "sockopt":{
                "tproxy":"tproxy",
                "mark":255
            }
        }
    },
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "udp": true
      }
    },
    {
      "port": 1081,
      "listen": "0.0.0.0",
      "protocol": "http",
      "settings": {
        "udp": true
      }
    }],
    "outbounds": [{
      "tag": "socks-out",
      "protocol": "socks",
      "settings": {
        "servers": [{
          "address": "10.20.0.1",
          "port": 1080
        }]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }]
}
```

## 防火墙 nftables

`/etc/nftables.conf`  

```nft
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
        chain input {
                type filter hook input priority filter;
        }
        chain forward {
                type filter hook forward priority filter;
        }
        chain output {
                type filter hook output priority filter;
        }
}
```

`/etc/nftables/rules.v4`  

```nft
table ip v2ray {
        chain prerouting {
                type filter hook prerouting priority filter; policy accept;
                ip daddr { 10.0.0.0/8, 100.64.0.0/10, 127.0.0.1, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255 } return
                ip saddr { 100.64.0.0/10, 172.16.0.0/12 } return
                meta mark 0x000000ff return
                meta l4proto { tcp, udp } meta mark set 0x00000001 tproxy to 127.0.0.1:3316 accept
        }
}
table ip filter {
        chain divert {
                type filter hook prerouting priority mangle; policy accept;
                meta l4proto tcp socket transparent 1 meta mark set 0x00000001 accept
        }
}
```
