# Debian Router

## Summary

    虚拟软件路由OpenBSD替换为Debian
    只是由于OpenBSD用的人太少了出了问题文档较少所以决定使用Debian12 完成路由综合功能

### 网络工具

```bash
apt install -y dnsmasq ifupdown nfs-common samba net-tools tcpdump bridge-utils iptraf iftop openssl unzip vim-tiny tree wget curl iptables-persistent
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

### 常用工具

```bash
# apt install v2ray privoxy iftop
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

### zfs

```bash
apt install zfsutils-linux
# 查看Pool
zpool list
# 查看volumes
zfs list
# 从data pool创建文件系统
zfs create data/tank

# 获取data/tank的安装点
zfs get mountpoint data/tank
# 检查是否已挂载
zfs get mounted data/tank
zfs set mountpoint=/YOUR-MOUNT-POINT pool/fs
zfs set mountpoint=/my_vms data/tank
cd /my_vms
df /my_vms
zfs get mountpoint data/tank
zfs get mounted data/tank

# 使用-a选项可以挂载所有ZFS托管文件系统。
zfs mount -a
# 查看挂载情况
zfs mount
# 卸载ZFS文件系统
zfs unmount data/tank

# 加载已有pool
zpool import -f pool-vm

```

### virt-zfs support

```bash
apt install libvirt-daemon-driver-storage-zfs

# define Pool zfs-pool-vm
[virsh]
pool-define-as --name zfs-pool-vm --source-name filepool --type zfs
pool-start zfs-pool-vm
pool-info zfs-pool-vm
pool-autostart zfs-pool-vm
vol-list zfs-pool-vm

```

### qcow2 as zfs-vol && zfs-vol as qcow2

```bash
[virsh]
# img 2 zvol
vol-upload --pool zfs-pool-vm --vol vol1 --file /home/novel/FreeBSD-10.0-RELEASE-amd64-memstick.img
# zvol 2 img
vol-download --pool zfs-pool-vm --vol vol1 --file /home/novel/zfsfilepool_vol1.img
# create vol
vol-create-as --pool zfs-pool-vm --name vol2 --capacity 1G
# delete vol
vol-delete --pool zfs-pool-vm vol2

```

### libvirt

```bash
# Define VM
<disk type='volume' device='disk'>
    <source pool='zfs-pool-vm' volume='vol1'/>
    <target dev='vdb' bus='virtio'/>
</disk>

# Define Pool as zfs
<pool type='zfs'>
  <name>zfs-pool-vm</name>
  <source>
    <name>pool-vm</name>
  </source>
  <target>
    <path>/dev/zvol/pool-vm</path>
  </target>
</pool>

# or
<pool type="zfs">
  <name>myzfspool</name>
  <source>
    <name>zpoolname</name>
    <device path="/dev/ada1"/>
    <device path="/dev/ada2"/>
  </source>
</pool>

# Defile Pool as Directory
<pool type="dir">
  <name>virtimages</name>
  <target>
    <path>/var/lib/virt/images</path>
  </target>
</pool>

# Define Pool as nfs
<pool type="netfs">
  <name>virtimages</name>
  <source>
    <host name="nfs.example.com"/>
    <dir path="/var/lib/virt/images"/>
    <format type='nfs'/>
  </source>
  <target>
    <path>/var/lib/virt/images</path>
  </target>
</pool>
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

### Caddy Web服务

```bash
# 下载
https://github.com/caddyserver/caddy/releases/download/v2.7.4/caddy_2.7.4_linux_amd64.tar.gz

# 解压
tar zxvf caddy_2.7.4_linux_amd64.tar.gz
sudo groupadd --system caddy
sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy

# /usr/lib/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/caddy/caddy run --environ --config /usr/local/caddy/Caddyfile
ExecReload=/usr/local/caddy/caddy reload --config /usr/bin/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target

```
