#!/bin/bash

DATE=`date "+%y%m%d%H%M%S"`
ETC_DIR=/etc

# create deploy directory
mk_work_dir() {
    DEP_DIR=/opt/debrt; mkdir -p $DEP_DIR
}

check_fmt_cidr() {
    read -p "Input: " ip_address <<< ${1}
    if [[ $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

check_fmt_addr() {
    read -p "Input: " ip_address <<< ${1}
    if [[ $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

mask2cdr() {
   # Assumes there's no "255." after a non-255 byte in the mask
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
}

cdr2mask() {
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

# get network number
get_network_no() {

    IFS=. read -r i1 i2 i3 i4 <<< ${1}
    mask=`cdr2mask ${2}`;
    IFS=. read -r m1 m2 m3 m4 <<< ${mask}
    printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
    return 0;
}

# get network broadcast
get_network_broadcast() {
    IFS=. read -r i1 i2 i3 i4 <<< ${1}
    mask=`cdr2mask ${2}`;
    IFS=. read -r m1 m2 m3 m4 <<< ${mask}
    printf "%d.%d.%d.%d\n" "$((i1 | (0xFF^m1)))" "$((i2 | (0xFF^m2)))" "$((i3 | (0xFF^m3)))" "$((i4 | (0xFF^m4)))"
    return 0;
}

valid_cidr() {
    CIDR="$1"
    # ret=check_fmt_cidr $CIDR
    check_fmt_cidr ${CIDR}
    if [ $? -ne 0 ]; then
        echo "IP address format error! exp: [x.x.x.x/n]"
        return 1
    fi
    check_fmt_cidr
    # Parse "a.b.c.d/n" into five separate variables
    IFS="./" read -r ip1 ip2 ip3 ip4 mask_num <<< "${CIDR}"

    # Convert IP address from quad notation to integer
    ip=$(($ip1 * 256 ** 3 + $ip2 * 256 ** 2 + $ip3 * 256 + $ip4))

    # Remove upper bits and check that all ${mask_num} lower bits are 0
    if [ $ip1 -ge 0 ] && [ $ip1 -le 255 ] \
    && [ $ip2 -ge 0 ] && [ $ip2 -le 255 ] \
    && [ $ip3 -ge 0 ] && [ $ip3 -le 255 ] \
    && [ $ip4 -ge 0 ] && [ $ip4 -le 255 ] \
    && [ ${mask_num} -ge 0 ] && [ ${mask_num} -le 32 ]
    then
        ipaddr=${ip1}.${ip2}.${ip3}.${ip4}
        mask=`cdr2mask ${mask_num}`;
        network=`get_network_no ${ipaddr} ${mask_num}`;
        echo "${ipaddr}|${mask}|${mask_num}|${network}"
        return 0
    else
        echo "IP address over range! [0.0.0.0/0-255.255.255.255/32]";
        return 1
    fi
}


# show interface status
show_iface() {
    ip -br l show 2>/dev/null | awk '$0 !~ "lo|vir|wl|vnet|veth"{print $0}'
}

# check interface list, return error interface
# return: code|str : 0-ok,3-done
check_iface_list() {
    # check done
    v_iface=(${1})
    if [ "${v_iface[0]}" == "done" ] || [ "${v_iface[0]}" == "exit" ] ; then
        echo "3|done"
        return 3
    fi

    # check interface exist
    declare -A M_IFALL=()
    v_ifall=(`ip -br l show 2>/dev/null| awk '$0 !~ "lo|vir|wl|vnet|veth"{print $1}'`)

    for i in "${v_ifall[@]}"; do
        M_IFALL["${i}"]=${i}
    done

    declare -A M_IFACE=()
    err_not_exist=""
    for i in "${v_iface[@]}"; do
        M_IFACE["${i}"]=${i}
        if [ "${i}" != "${M_IFALL["${i}"]}" ] ; then
            err_not_exist="${err_not_exist} '${i}'"
        fi
    done

    # error: iface not exist!
    if [ "${err_not_exist}" != "" ]; then
        echo "1|${err_not_exist} not exist"
        return 1
    fi

    # check if the iface is used
    err_used_iface=""
    for k in ${!M_INET[@]}; do
        if [ "${k}" != "_gw" ]; then
            IFS="|" read -r addr mask mask_num network iface itype <<< ${M_INET[$k]}
            v_ifused=(${iface})
            declare -A M_IFUSED=()
            for i in "${v_ifused[@]}"; do
                M_IFUSED["${i}"]=${i}
            done
            for i in ${!M_IFACE[@]}; do
                if [ "${i}" == "${M_IFUSED[${i}]}" ]; then
                    err_used_iface="${err_used_iface} '${i}' used in '${k}'"
                fi
            done
        fi
    done

    # error: iface is used!
    if [ "${err_used_iface}" != "" ]; then
        echo "2|${err_used_iface}"
        return 2
    fi

    # deduplication
    ret_iface_list=""
    for k in ${!M_IFACE[@]}; do
        ret_iface_list="${ret_iface_list} ${k}"
    done

    echo "0|${ret_iface_list}"
    return 0
}
# declare map interfaces data
declare -A M_INET=()

# config interface
conf_iface() {
    let LAN_FLAG=0
    while true; do
        show_iface;
        NET_MARK=''
        if [ ${LAN_FLAG} -eq 0 ]; then
            NET_MARK='wan'
            read -p "Input WAN interface name or 'done': " iface
        else
            NET_MARK=vlan${LAN_FLAG}
            read -p "Input LAN${LAN_FLAG} interface list [ethx1 ethx2...] or 'done': " iface
        fi

        # check iface list
        IFS="|" read -r code value <<< `check_iface_list ${iface}`

        if [ "${code}" == "0" ] ; then

            while true; do
                read -p "Input ${NET_MARK} IP address [x.x.x.x/n]: " ipaddr
                result="$(valid_cidr ${ipaddr})|${iface}|${LAN_FLAG}"

                if [ $? -ne 0 ]; then
                    echo "[${iface}] IP address error!, input again!"
                    continue;
                else
                    M_INET[${NET_MARK}]=${result}
                    break;
                fi
            done

            # Gateway & DNS
            if [ ${LAN_FLAG} -eq 0 ]; then
                M_INET["_gw"]="${iface}"
                while true; do
                    read -p "Input default gateway [x.x.x.x]: " gw
                    check_fmt_addr ${gw}
                    if [ $? -ne 0 ]; then
                        echo "IP address format error! exp: [10.0.0.1]"
                        continue;
                    else
                        M_INET["_gw"]="${M_INET["_gw"]}|${gw}"
                        break;
                    fi
                done

                while true; do
                    read -p "Input DNS [x.x.x.x]: " dns1
                    check_fmt_addr ${dns1}
                    if [ $? -ne 0 ]; then
                        echo "IP address format error! exp: [1.1.1.1]"
                        continue;
                    else
                        M_INET["_gw"]="${M_INET["_gw"]}|${dns1}"
                        break;
                    fi
                done
            fi
            let LAN_FLAG++
        elif [ "${code}" == "3" ] ; then
            break;
        else
            echo "Error: [${code}], ${value} ,please input again!"
        fi
    done

    printf "\n"
    # Note that we're stepping through KEYS here, not values.
    for k in ${!M_INET[@]}; do
        printf '"%s: %s"\n' "${k}" "${M_INET[${k}]}"
    done

}

# install packages
install_pkg() {
    apt update -y;
    apt install -y dnsmasq ifupdown nfs-common samba
    apt install -y net-tools tcpdump bridge-utils iptraf iftop openssl
    apt install -y unzip vim-tiny tree wget curl
    apt install -y munin nginx-full openvpn easy-rsa
    # iptables save
    apt install -y iptables-persistent
}

# network setting
network_set() {
    # create interfaces directory
    mkdir -p ${ETC_DIR}/network/interfaces.d
    mkdir -p ${ETC_DIR}/network/if-up.d/
    rm ${ETC_DIR}/network/interfaces.d/*.iface
    # ip address setting
    echo -e "source ${ETC_DIR}/network/interfaces.d/*\n" > ${ETC_DIR}/network/interfaces

    # loopback
    echo -e "# The loopback network interface\nauto lo\n\tiface lo inet loopback \n" > ${ETC_DIR}/network/interfaces.d/lo.iface

    LAN_CFILE=""
    WAN_CFILE=""
    RUT_CFILE="#!/bin/sh"
    for k in ${!M_INET[@]}; do
        if [ "${k}" != "_gw" ]; then
            IFS="|" read -r addr mask mask_num network iface itype <<< ${M_INET[$k]}

            if [ ${itype} -eq 0 ]; then
                IFS="|" read -r ifwan gw dns1 <<< ${M_INET["_gw"]}

                WAN_CFILE="${WAN_CFILE}# The WAN network interface\n"
                WAN_CFILE="${WAN_CFILE}auto ${iface}\n"
                WAN_CFILE="${WAN_CFILE}\tiface ${iface} inet static\n"
                WAN_CFILE="${WAN_CFILE}\taddress ${addr}/${mask_num}\n"
                WAN_CFILE="${WAN_CFILE}\tgateway ${gw}\n"
                WAN_CFILE="${WAN_CFILE}\tdns-nameservers $dns1\n"
            else
                LAN_CFILE="${LAN_CFILE}# The LAN${itype} network interface\n"
                LAN_CFILE="${LAN_CFILE}auto ${k}\n"
                LAN_CFILE="${LAN_CFILE}\tiface ${k} inet static\n"
                LAN_CFILE="${LAN_CFILE}\taddress ${addr}/${mask_num}\n"
                LAN_CFILE="${LAN_CFILE}\tbridge_ports ${iface}\n"
                LAN_CFILE="${LAN_CFILE}\tbridge_stp on\n"

                if [ "${RUT_CFILE}" == "#!/bin/sh" ]; then
                    RUT_CFILE="${RUT_CFILE}\n"
                    RUT_CFILE="${RUT_CFILE}if [ \"\$IFACE\" = \"${k}\" ]; then\n"
                else
                    RUT_CFILE="${RUT_CFILE}elif [ \"\$IFACE\" = \"${k}\" ]; then\n"
                fi
                RUT_CFILE="${RUT_CFILE}\t# ip route add ${network}/24 via XXX.XXX.XXX.XXX\n\treturn\n"
            fi
        fi
    done

    echo -e "${WAN_CFILE}" >> ${ETC_DIR}/network/interfaces.d/wan.iface
    echo -e "${LAN_CFILE}" >> ${ETC_DIR}/network/interfaces.d/vlan.iface
    echo -e "${RUT_CFILE}fi" > ${ETC_DIR}/network/if-up.d/route
    chmod +x ${ETC_DIR}/network/if-up.d/route
}

# kernel opt
ip_forward_set() {
    # ip_forward
    echo "net.ipv4.ip_forward = 1" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> ${ETC_DIR}/sysctl.conf

    # other kernel opt
    echo "net.ipv4.tcp_syncookies = 1" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse = 1" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_fin_timeout = 30" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_keepalive_time = 1200" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.ip_local_port_range = 10000 65000" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 8192" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_max_tw_buckets = 5000" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_fastopen = 3" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_mem = 25600 51200 102400" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_rmem = 4096 87380 67108864" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_wmem = 4096 65536 67108864" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_mtu_probing = 1" > ${ETC_DIR}/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" > ${ETC_DIR}/sysctl.conf

    sysctl -p
}

# iptables setting
iptables_set() {
    # get WAN iface info
    IFS="|" read -r ifwan gw dns1 <<< ${M_INET["_gw"]}

    # LAN interface
    iptables -t nat -A POSTROUTING -o ${ifwan} -j MASQUERADE
    ip6tables -t nat -A POSTROUTING -o ${ifwan} -j MASQUERADE
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
}

# dnsmasq setting
dnsmasq_set() {

    # create dnsmasq directory
    mkdir -p ${ETC_DIR}/dnsmasq.d/;
    mkdir -p /var/log/dnsmasq/

    # dnsmasq dhcp
    DHCP_LISTEN="listen-address=127.0.0.1"
    DNS_ADDRESS=""
    for k in ${!M_INET[@]}; do
        if [ "${k}" != "_gw" ]; then
            IFS="|" read -r addr mask mask_num network iface itype <<< ${M_INET[$k]}
            if [ ${itype} -ne 0 ]; then
                broadcast=`get_network_broadcast ${addr} ${mask_num}`

                DHCP_LISTEN="${DHCP_LISTEN},${addr}"
                DHCP_RANGE="${DHCP_RANGE}dhcp-range=interface:${k},${network},${broadcast},48h\n"
                DNS_ADDRESS="${DNS_ADDRESS}address=/${k}.games.play/${addr}\n"
            fi
        fi
    done

    DHCP_RANGE="${DHCP_RANGE}resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf\n"
    DHCP_RANGE="${DHCP_RANGE}log-facility=/var/log/dnsmasq/dnsmasq.log\n"
    DHCP_RANGE="${DHCP_RANGE}log-async=100\n"
    DHCP_RANGE="${DHCP_RANGE}conf-dir=/etc/dnsmasq.d\n";

    echo -e "${DHCP_LISTEN}\n${DHCP_RANGE}" > ${ETC_DIR}/dnsmasq.conf

    # dnsmasq address
    echo -e "${DNS_ADDRESS}" > ${ETC_DIR}/dnsmasq.d/address.conf

    # get WAN iface info
    IFS="|" read -r ifwan gw dns1 <<< ${M_INET["_gw"]}

    # dnsmasq resolv
    echo "all-servers
    server=/cn/114.114.114.114
    server=${dns1}
    server=/google.com/8.8.8.8" > ${ETC_DIR}/dnsmasq.d/resolv.dnsmasq.conf
}

# start server
start_server() {
    systemctl enable --now networking
    systemctl enable --now sambd
    systemctl enable --now rpcbind
    systemctl enable --now sshd
    systemctl enable --now dnsmasq
    systemctl enable --now munin
    systemctl enable --now nginx
}

# stop systemd server
stop_systemd() {
    mv ${ETC_DIR}/resolv.conf ${ETC_DIR}/resolv.conf.${DATE}

    # get WAN iface info
    IFS="|" read -r ifwan gw dns1 <<< ${M_INET["_gw"]}

    # dnsmasq resolv
    echo "nameserver ${dns1}" >> ${ETC_DIR}/resolv.conf
    systemctl disable --now systemd-resolved.service
    systemctl disable --now systemd-networkd.socket systemd-networkd.service
    # sudo systemctl mask systemd-networkd

    # remove
    apt remove -y systemd-resolved
    mv /usr/lib/systemd/system/systemd-networkd.service /usr/lib/systemd/system/systemd-networkd.service.bak
    mv /usr/lib/systemd/system/systemd-networkd.socket /usr/lib/systemd/system/systemd-networkd.socket.bak

    rm -f /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
    rm -f /etc/systemd/system/dbus-org.freedesktop.network1.service
    rm -f /etc/systemd/system/sockets.target.wants/systemd-networkd.socket
    rm -f /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
    rm -f /etc/systemd/system/sysinit.target.wants/systemd-network-generator.service
}

# munin nginx server
munin_set() {
    rm /etc/nginx/sites-enabled/default
    /etc/nginx/conf.d/server.conf
    echo 'server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        # Add index.php to the list if you are using PHP
        index index.html index.htm index.nginx-debian.html;
        server_name _;

        location / {
                alias /var/cache/munin/www/;
        }
}' > /etc/nginx/conf.d/server.conf

}

main() {
    echo "--------------start---------------"
    install_pkg;
    # ip forward setting
    ip_forward_set;
    # config interface
    conf_iface;
    # network setting
    network_set;
    # sys init
    stop_systemd;
    # iptables setting
    iptables_set;
    # dnsmasq setting
    dnsmasq_set;
    # munin setting
    munin_set;
    # start server
    start_server;
    # restart system
    reboot;
    echo "--------------finish---------------"
}

main;
