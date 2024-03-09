# Network

## Summary

### 网络划分

wifi-router(192.168.31.254) {DNS, DHCP} -- [route:10.x.x.x via 192.168.31.1]
    |
gateway(192.168.31.1)-(192.168.21.1) {DNS,DHCP} -- [route:192.168.21.x via 192.168.21.1]
                                                -->[route:10.x.x.x via 192.168.31.2]
    |
zpl-vms(192.168.31.64)-(10.21.0.26)

    vroute-vms-1(bridge: 192.168.31.2) default: 192.168.31.1
            -(10.21.0.1) [vnet-vms-bridge0] --> [route to: 10.11.x.x via 10.21.0.254]
            -(10.21.1.1) [vnet-vms-internel]
    vroute-vms-2(bridge: 10.21.0.254) default: 10.21.0.1
            -(10.21.2.1) [vnet-vms-brlan0]

NUC (192.168.31.198)-(10.21.0.198)-(10.11.0.198)

    vroute-fed-1(bridge: 10.21.0.254) default: 10.21.0.1
    -(10.21.0.254) [vnet-fed-bridge0]
    -(10.11.1.1) [vnet-fed-internel]