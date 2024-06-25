# Debian Router

## Summary

构建Debian虚拟软件路由替换OpenBSD

### 网络工具

```bash
apt install -y dnsmasq ifupdown nfs-common samba net-tools tcpdump bridge-utils iptraf iftop privoxy openssl unzip vim-tiny tree wget curl iptables-persistent munin nginx-full openvpn pppoeconf

```

### 网络接口管理

```bash
# 使用networking服务管理网络接口 如使用NetwokManager管理网络请参考其文档
# /etc/network/interfaces.d/static.iface
# The loopback network interface
auto lo
iface lo inet loopback
# The WAN network interface
auto eno1
        iface eno1 inet static
        address 192.168.21.254/24
        gateway 192.168.21.1
        dns-nameservers 192.168.21.1
# The brlan0 network interface
auto brlan0
        iface brlan0 inet static
        address 10.21.0.1/24
        bridge_ports eth0
        bridge_stp on
# The LAN1 network interface
auto enp1s0
        iface enp1s0 inet static
        address 10.43.0.1/24
```

### WAN pppoe拨号

```bash
pppoeconf
```

### 开启路由转发

```bash
# /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p
```

### 内核优化

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

### iptables设置

```bash
# 设置NAT 表规则,ethx0为出WAN网口
iptables -t nat -A POSTROUTING -o ethx0 -j MASQUERADE
iptables -L -n -t nat
iptables-save
```

### Privoxy

```bash
# /etc/privoxy/config
user-manual /usr/share/doc/privoxy/user-manual
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile match-all.action # Actions that are applied to all sites and maybe overruled later on.
actionsfile default.action   # Main actions file
actionsfile user.action      # User customizations
filterfile default.filter
filterfile user.filter      # User customizations
logfile logfile
listen-address  [::1]:8118
listen-address  0.0.0.0:8118
toggle  1
enable-remote-toggle  0
enable-remote-http-toggle  0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 0
forward-socks5t   /               127.0.0.1:1080 .
forwarded-connect-retries  0
accept-intercepted-requests 0
allow-cgi-request-crunching 0
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
```

### dnsmasq

[dnsmasq setup](./dnsmasq.md)

### munin Nginx 设置

```conf
# rm /etc/nginx/sites-enabled/default
# /etc/nginx/conf.d/server.conf
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;
        server_name _;

        location / {
                alias /var/cache/munin/www/;
        }
}
```

### Samba基本配置

```bash
# /etc/samba/smb.conf
[usr1]
comment = Work Dir
path = /home/usr1
public = yes
writeable = yes
browseable = yes

# 添加用户名/密码
smbpasswd -a usr1

# 重启samba
systemctl restart smbd
# 设置开机启动
systemctl enable smbd

# 免密码配置 加上 "security" 和 "map to guest" debian12
# /etc/samba/smb.conf
[global]
    security = user
    map to guest = Bad User
[public-dir]
    comment = Work Dir
    path = /public-dir/
    public = yes
    writeable = yes
    browseable = yes
    guest ok = yes

# 其它文件服务 To-do
samba
nfs
ftp
webdav
```

### frp内网穿透

```bash
[项目地址]https://github.com/fatedier/frp
[frp下载](https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz)
# 解压
tar zxvf frp_0.51.3_linux_amd64.tar.gz -C /usr/local
cd /usr/local
ln -s frp_0.51.3_linux_amd64 frp
# 修改配置文件
# frpc.ini
[common]
server_addr = frps.example.com
server_port = 7112
token = token-value

[nuc_ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 64101

# 添加服务启动项
# /usr/lib/systemd/system/frpc.service
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/local/frp/frpc -c /usr/local/frp/frpc.ini

[Install]
WantedBy=multi-user.target

# 启动服务
systemctl enable --now frpc

```

### hostapd

```bash
# /etc/network/interfaces.d/brlan0.iface
auto brlan0
iface brlan0 inet dhcp
        pre-up hostapd -B /etc/hostapd/hostapd.conf

# /etc/hostapd/hostapd.conf
# the interface used by the AP
interface=wlan0
driver=nl80211
bridge=brlan0

# "g" simply means 2.4GHz band a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g, ad = IEEE 802.11ad (60 GHz)
hw_mode=g
# the channel to use
channel=11
# limit the frequencies used to those allowed in the country
ieee80211d=1
# the country code
country_code=FR
# 802.11n support
ieee80211ac=1
# QoS support, also required for full speed on 802.11n/ac/ax
wmm_enabled=1

ht_capab=[HT40-][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40][40-INTOLERANT][GF]

# the name of the AP
ssid=AP-TOM
# 1=wpa, 2=wep, 3=both
auth_algs=1
# WPA2 only
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=XXXXXXXX
```
