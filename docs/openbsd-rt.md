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

```sh
#################################
#### Packet Firewall Ruleset ####
#################################

###################
#### Variables ####
###################

# External interface
ext_if="rum0"

# Internal interface
int_if="rl1"

# Follow RFC1918 and don't route to non-routable IPs
# http://www.iana.org/assignments/ipv4-address-space
# http://rfc.net/rfc1918.html
nonroute= "{ 0.0.0.0/8, 20.20.20.0/24, 127.0.0.0/8, 169.254.0.0/16,
        172.16.0.0/12, 192.0.2.0/24, 192.168.0.0/16, 224.0.0.0/3,
        255.255.255.255 }"

# Set allowed ICMP types
# Blocking ICMP entirely is bad practice and will break things,
# FreeBSD applies rate limiting by default to mitigate attacks.
icmp_types = "{ 0, 3, 4, 8, 11, 12 }"

####################################
#### Options and optimizations #####
####################################

# Set interface for logging (statistics)
set loginterface $ext_if

# Drop states as fast as possible without having excessively low timeouts
set optimization aggressive

# Block policy, either silently drop packets or tell sender that request is blocked
set block-policy return

# Don't bother to process (filter) following interfaces such as loopback:
set skip on lo0

# Scrub traffic
# Add special exception for game consoles such as PS3 and PS4 (NAT type 2 vs 3)
# scrub from CHANGEME to any no-df random-id fragment reassemble
scrub on $ext_if all no-df fragment reassemble

#######################
#### NAT & Proxies ####
#######################

# Enable NAT and tell pf not to change ports if needed
# Add special exception for game consoles such as PS3 and PS4 (NAT type 2 vs 3)
# ie static-port mapping. Do NOT enable both rules.
# nat on $ext_if from $int_if:network to any -> ($ext_if) static-port
nat on $ext_if from $int_if:network to any -> ($ext_if)

# Redirect ftp connections to ftp-proxy
rdr pass on $int_if inet proto tcp from $int_if:network to any port 21 -> 127.0.0.1 port 8021

# Enable ftp-proxy (active connections)
# nat-anchor "ftp-proxy/*"
# rdr-anchor "ftp-proxy/*"

# Enable UPnP (requires miniupnpd, game consoles needs this)
# rdr-anchor "miniupnpd"

# Anchors needs to be set after nat/rdr-anchor
# Same as above regarding miniupnpd
# anchor "ftp-proxy/*"
# anchor "miniupnpd"

################################
#### Rules inbound (int_if) ####
################################

# Pass on everything incl multicast
pass in quick on $int_if from any to 239.0.0.0/8
pass in quick on $int_if inet all keep state

#################################
#### Rules outbound (int_if) ####
#################################

# Pass on everything incl multicast
pass out quick on $int_if from any to 239.0.0.0/8
pass out quick on $int_if inet all keep state

################################
#### Rules inbound (ext_if) ####
################################

# Drop packets from non-routable addresses immediately
block drop in quick on $ext_if from $nonroute to any

# Allow DHCP
pass in quick on $ext_if inet proto udp to ($ext_if) port { 67, 68 }

# Allow SSH & HTTP
pass in quick on $ext_if inet proto tcp to ($ext_if) port { 22, 80 }

# Allow ICMP
pass in quick on $ext_if inet proto icmp all icmp-type $icmp_types

# Allow FTPs to connect to the FTP-proxy
# pass in quick on $ext_if inet proto tcp to ($ext_if) port ftp-data user proxy

# Block everything else
block in on $ext_if all

#################################
#### Rules outbound (ext_if) ####
#################################

# Drop packets to non-routable addresses immediately, allow everything else
block drop out quick on $ext_if from any to $nonroute
pass out on $ext_if all
```

`pfctl -f /etc/pf.conf`

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
