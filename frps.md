# frp内网穿透

## Summary

### 获取软件

    [项目地址]https://github.com/fatedier/frp
    [frp下载](https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz)

### 安装&配置

```bash
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
