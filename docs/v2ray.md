# V2ray configuration

## downloads

```bash
# linux:
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-linux-64.zip
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-linux-arm64-v8a.zip

# freebsd
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-freebsd-64.zip
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-freebsd-arm64-v8a.zip

# openbsd
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-openbsd-64.zip
https://github.com/v2fly/v2ray-core/releases/download/v5.14.1/v2ray-openbsd-arm64-v8a.zip
```

## install

`unzip -d /usr/local/v2ray v2ray-*.zip`

## configure

`/usr/local/v2ray/config.json`

```json
{
  "inbounds": [
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks"
    },
    {
      "port": 8118,
      "listen": "0.0.0.0",
      "protocol": "http",
      "settings": {
        "accounts": [
          {
            "user": "user",
            "pass": "password"
          }
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "706f4b83b9c6d.example.net",
            "port": 443,
            "users": [
              {
                "id": "3e14c9fdf78dc57c4df706f4b83b9c6d"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false,
          "serverName": "706f4b83b9c6d.example.net"
        },
        "tcpSettings": null,
        "kcpSettings": null,
        "wsSettings": {
          "connectionReuse": true,
          "path": "/path",
          "headers": {
            "Host": "706f4b83b9c6d.example.net"
          }
        },
        "httpSettings": null,
        "quicSettings": null
      }
    },
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "706f4b83b9c6d.example.net",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}
```

## systemd

`/lib/systemd/system/v2ray.service`

```ini
[Unit]
Description=V2Ray Service
Documentation=https://www.v2ray.com/ https://www.v2fly.org/
After=network-online.target nss-lookup.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
DynamicUser=true
NoNewPrivileges=true
Environment=V2RAY_LOCATION_ASSET=/usr/local/v2ray
# ExecStart=/usr/local/v2ray/v2ray -config /usr/local/v2ray/config.json
ExecStart=/usr/local/v2ray/v2ray run /usr/local/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## rc.d

`/usr/local/etc/rc.d/v2ray`

```bash
#!/bin/sh

# PROVIDE: v2ray
# REQUIRE: netif NETWORKING ipmon ipfw netwait
# BEFORE: LOGIN
# KEYWORD:

. /etc/rc.subr

name="v2ray"
rcvar=v2ray_enable

start_precmd="v2ray_checkconfig"
restart_precmd="v2ray_checkconfig"
reload_precmd="v2ray_checkconfig"
configtest_cmd="v2ray_checkconfig"
command="/usr/local/v2ray/v2ray"
command_args="&"
# required_files=/usr/local/etc/${name}_config.json
required_files=/usr/local/v2ray/config.json
extra_commands="reload configtest"
v2ray_user=www
v2ray_group=www

load_rc_config "v2ray"

v2ray_configfile="/usr/local/v2ray/config.json"
v2ray_flags="run ${v2ray_configfile}"

v2ray_checkconfig()
{
 # eval ${command} ${v2ray_flags} -test
 eval ${command} ${v2ray_flags}
}

run_rc_command "$1"
```
