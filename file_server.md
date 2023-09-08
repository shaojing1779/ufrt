# 文件共享

## debian文件共享配置

### Samba基本配置

```bash
# 安装samba
apt install samba

# /etc/samba/smb.conf
[usr1]
comment = Work Dir
path = /home/usr1
public = yes
writeable = yes
browseable = yes
guest ok = no
read only = no

# 添加用户名/密码
smbpasswd -a usr1

# 重启samba
systeamctl restart smbd
# 设置开机启动
systeamctl restart smbd

```

###  reference

```bash

```
