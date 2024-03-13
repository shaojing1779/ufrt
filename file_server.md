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

```

### reference

```bash
samba
nfs
ftp
webdav
```
