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
    sudo service smbd restart

    