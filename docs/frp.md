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
# REQUIRE: DAEMON NETWORKING netwait
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

## freebsd multiple services

/usr/local/etc/rc.d/frpc-internal  

```sh
#!/bin/sh

# PROVIDE: frpc_internal
# REQUIRE: DAEMON NETWORKING netwait
# KEYWORD: shutdown

. /etc/rc.subr

name="frpc"
rcvar="frpc_internal_enable"

load_rc_config $name

: ${frpc_enable="NO"}
: ${frpc_user="nobody"}
: ${frpc_flags=""}
: ${frpc_conf="/usr/local/frp/frpc-internal.toml"}

daemon_pidfile="/var/run/frpc-internal-daemon.pid"
pidfile="/var/run/frpc-internal.pid"
command="/usr/local/frp/frpc"
command_args="-c ${frpc_conf}"
start_cmd="/usr/sbin/daemon -r -R 5 -u $frpc_user -P $daemon_pidfile -p $pidfile -t $name $command $command_args $frpc_flags"
start_postcmd="${name}_start"
stop_cmd="${name}_stop"

frpc_start()
{
    echo "${name}_daemon running pid `cat ${daemon_pidfile}`."
    echo "${name} running pid `cat ${pidfile}`."
}

frpc_stop()
{
    if [ -f "$daemon_pidfile" ]; then
        pid=`cat $daemon_pidfile`
        echo "Stopping pid ${pid}."
        kill $pid
    else
            echo "${name} not running?"
    fi
}


run_rc_command "$1"
```

/usr/local/etc/rc.d/frpc-external  

```sh
#!/bin/sh

# PROVIDE: frpc_external
# REQUIRE: DAEMON NETWORKING netwait
# KEYWORD: shutdown

. /etc/rc.subr

name="frpc"
rcvar="frpc_external_enable"

load_rc_config $name

: ${frpc_enable="NO"}
: ${frpc_user="nobody"}
: ${frpc_flags=""}
: ${frpc_conf="/usr/local/frp/frpc-external.toml"}

daemon_pidfile="/var/run/frpc-external-daemon.pid"
pidfile="/var/run/frpc-external.pid"
command="/usr/local/frp/frpc"
command_args="-c ${frpc_conf}"
start_cmd="/usr/sbin/daemon -r -R 5 -u $frpc_user -P $daemon_pidfile -p $pidfile -t $name $command $command_args $frpc_flags"
start_postcmd="${name}_start"
stop_cmd="${name}_stop"

frpc_start()
{
    echo "${name}_daemon running pid `cat ${daemon_pidfile}`."
    echo "${name} running pid `cat ${pidfile}`."
}

frpc_stop()
{
    if [ -f "$daemon_pidfile" ]; then
        pid=`cat $daemon_pidfile`
        echo "Stopping pid ${pid}."
        kill $pid
    else
            echo "${name} not running?"
    fi
}


run_rc_command "$1"
```

`chmod +x /usr/local/etc/rc.d/frpc-*`  
`service frpc-internal enable`  
`service frpc-internal start`  
`service frpc-external enable`  
`service frpc-external start`  
