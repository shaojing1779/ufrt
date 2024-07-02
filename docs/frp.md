# FRP

## downloads

```bash
# Linux
https://github.com/fatedier/frp/releases/download/v0.58.1/frp_0.58.1_freebsd_amd64.tar.gz

# FreeBSD
https://github.com/fatedier/frp/releases/download/v0.58.1/frp_0.58.1_freebsd_amd64.tar.gz
```

## install

`tar zxvf frp_*.tar.gz -C /usr/local/`

`ln -s /usr/local/frp /usr/local/frp_0.58.1_freebsd_amd64/`

## configure

### frps

`/usr/local/frp/frps.toml`

```toml
bindPort = 7112

auth.method = "token"
auth.token = "sonic"
```

### frpc

```toml
serverAddr = "SERVER_IP_ADDR"
serverPort = 7112
auth.method = "token"
auth.token = "sonic"

[[proxies]]
name = "hostname-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 2222
```

## systemd

`/lib/systemd/system/frpc.service`

```toml
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/local/frp/frpc -c /usr/local/frp/frpc.toml

[Install]
WantedBy=multi-user.target
```

## freebsd rc.d

/usr/local/etc/rc.d/frpc

```sh
#!/bin/sh

# PROVIDE: frpc
# REQUIRE: netif NETWORKING netwait
# BEFORE:
# KEYWORD: shutdown

. /etc/rc.subr

name="frpc"
rcvar=frpc_enable
load_rc_config "frpc"

: ${frpc_enable="NO"}
: ${frpc_conf="/usr/local/frp/frpc.toml"}

required_files="${frpc_conf}"
command="/usr/local/frp/frpc"
command_args="-c ${frpc_conf} &"

run_rc_command "$1"
```

`chmod +x /usr/local/etc/rc.d/frpc`
`service frpc enable`
`service frpc start`
