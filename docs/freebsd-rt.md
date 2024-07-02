# FreeBSD as firewall

## BASIC FREEBSD CONFIGURATION

```bash
# install same  commonly used
pkg install vim bash sudo htop tree xauth wget curl nmap git cpuid pftop

# OpenBSD Packet Filter (PF) & ALTQ
kldload pf.ko
service pf enable
service pflog enable
service pfsync enable
```

/boot/loader.conf
`bridge_load="YES"`

## NETWORK INTERFACES

/etc/rc.conf

```ini
hostname="freebsd14"

# set wan
ifconfig_vtnet0="inet 10.21.0.254/24"
ifconfig_vtnet0_alias0="inet 192.168.31.1/24"
defaultrouter=10.21.0.1
gateway_enable="YES"

ifconfig_vtnet1="inet 10.11.0.254/24"

# set bridge lan
#cloned_interfaces="bridge0"
#ifconfig_bridge0="addm vtnet1 vtnet2"
#ifconfig_vtnet1="up"
#ifconfig_bridge0="inet 10.11.0.254/24"

sshd_enable="YES"
netwait_enable="YES"
netwait_if="vtnet0"
```

## PF SETUP

/etc/pf.conf

```ini
#################################
#### Packet Firewall Ruleset ####
#################################

###################
#### Variables ####
###################

# External interface
ext_if="vtnet0"

# Internal interface
int_if="vtnet1"

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

## FORWARDING

/etc/sysctl.conf

```sh
net.inet.ip.forwarding=1
net.inet6.ip6.forwarding=1
```

## DNSMASQ

[dnsmasq setup](./dnsmasq.md)

## REBOOT FREEBSD

shutdown -r +1 "The system will reboot in 1 minutes for maintenance."
