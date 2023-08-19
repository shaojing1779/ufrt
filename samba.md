## 安装

    sudo apt-get update
    sudo apt-get upgrade 
    sudo apt-get install samba

# 编辑配置文件
# /etc/samba/smb.conf
        [usr1]
        comment = Work Dir
        path = /home/usr1
        public = yes
        writeable = yes
        browseable = yes
        guest ok = no
        read only = no

# 重启samba
    systeamctl restart smbd


## reference
[如何在Debian上搭建Samba服务实现Windows访问](https://zhuanlan.zhihu.com/p/615725594#:~:text=%E5%9C%A8Debian%E7%B3%BB%E7%BB%9F%E4%B8%AD%EF%BC%8C%E5%8F%AF%E4%BB%A5%E4%BD%BF%E7%94%A8%E4%BB%A5%E4%B8%8B%E5%91%BD%E4%BB%A4%E5%AE%89%E8%A3%85Samba%E6%9C%8D%E5%8A%A1%EF%BC%9A%20sudo%20apt-get%20update%20sudo,apt-get%20upgrade%20sudo%20apt-get%20install%20samba)
