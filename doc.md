# Debian Router

## Summary

    虚拟软件路由OpenBSD替换为Debian
    只是由于OpenBSD用的人太少了出了问题文档较少所以决定使用Debian12 完成路由综合功能

### 网络工具

```bash
apt install -y dnsmasq ifupdown nfs-common samba net-tools tcpdump bridge-utils iptraf iftop privoxy openssl unzip vim-tiny tree wget curl iptables-persistent munin nginx-full openvpn
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

### 开启路由转发

```bash
# /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p
```

### iptables设置

```bash
# 设置NAT 表规则,ethx0为出WAN网口
iptables -t nat -A POSTROUTING -o ethx0 -j MASQUERADE
iptables -L -n -t nat
iptables-save
```

### dnsmasq

```bash
# /etc/dnsmasq.conf
listen-address=10.43.0.254,127.0.0.1
# listen-address=127.0.0.1

dhcp-range=10.43.0.50,10.43.0.150,48h
resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
log-facility=/var/log/dnsmasq/dnsmasq.log
log-async=100

conf-dir=/etc/dnsmasq.d

# /etc/dnsmasq.d/resolv.dnsmasq.conf
all-servers
server=202.106.0.20
server=192.168.31.254
server=114.114.114.114
server=8.8.8.8
server=168.95.1.1

address=/nas.coolbit.work/192.168.31.95
address=/nas/192.168.31.95
address=/nuc.coolbit.work/192.168.31.198
address=/nuc/192.168.31.198

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
systeamctl restart smbd
# 设置开机启动
systeamctl restart smbd

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
