## debian软路由

虚拟网络中以前一直使用OpenBSD配置简单有效
只是由于这个系统用的人太少了出了问题文档较少，不利于后面维护，所以决定转到debian11或者openwrt

### 开启路由转发

```bash
/etc/sysctl.conf
net.ipv4.ip_forward=1
sysctl -p

# 简写
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf && sysctl -p
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf && sysctl -p
apt install dnsmasq vim wget curl network-manager
```

### ip设置

```bash
nmcli con add con-name enp7s0_static ifname enp7s0 type ethernet autoconnect yes ipv4.method manual ipv4.addresses 10.43.0.254/24 ipv4.dns 114.114.114.114
nmcli con add con-name enp1s0_static ifname enp1s0 type ethernet autoconnect yes ipv4.method manual ipv4.addresses 192.168.31.1/24 ipv4.gateway 192.168.31.254 ipv4.dns 114.114.114.114
```

