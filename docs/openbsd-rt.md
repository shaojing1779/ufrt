---
title: 'Make Openbsd as Router'
date: 2023-08-30T19:05:00+08:00
keywords:
- openbsd
- router
- gateway
- unix
- pf
description: "Make Openbsd as Router"
draft: false
tags: [openbsd, router, gateway, pf]
---

## NETWORK INTERFACES

/etc/hostname.rl1

```ini
inet 192.168.2.254 255.255.255.0 NONE
```

/etc/hostname.rum0

```ini
up media autoselect mode 11g mediaopt hostap nwid <SSID> wpa wpaprotos wpa2 wpaakms psk wpapsk <SHARED KEY>
```

## BRIDGE INTERFACE

/etc/bridgename.bridge0

```ini
add rl1
add rum0
up
```

## ENABLE FORWARDING

/etc/sysctl.conf

```ini
net.inet.ip.forwarding=1
net.inet6.ip6.forwarding=1
```

## PF

/etc/pf.conf

```bash
int_if="rl1"
wlan_if="rum0"

pass quick on $int_if no state
pass quick on $wlan_if no state
```

## ENABLE DHCP

/etc/rc.conf.local

```ini
dhcpd_flags=""
```

/etc/dhcpd.interfaces

```ini
rl1
```

/etc/dhcpd.conf

```conf
shared-network LAN {
  option domain-name "example.net";
  option domain-name-servers <primary_dns_ip>, <secondary_dns_ip>;

  subnet 192.168.2.0 netmask 255.255.255.0 {
    option routers 192.168.2.254;
    range 192.168.2.32 192.168.2.127;
  }
}
```

## UNBOUND DNS SERVER

/var/unbound/etc/unbound.conf

```conf
server:
        interface: 192.168.31.1
        interface: 127.0.0.1
        interface: ::1

        access-control: 0.0.0.0/0 allow
        access-control: 127.0.0.0/8 allow
        access-control: 192.168.31.0/24 allow
        access-control: ::0/0 refuse
        access-control: ::1 allow

        hide-identity: yes
        hide-version: yes

        auto-trust-anchor-file: "/var/unbound/db/root.key"
        val-log-level: 2
        aggressive-nsec: yes
forward-zone:
        name: "."
        forward-addr: 114.114.114.114
        forward-addr: 64.6.64.6                 # Verisign
        forward-addr: 192.168.31.254
        forward-first: yes

remote-control:
        control-enable: yes
        control-interface: /var/run/unbound.sock

```
