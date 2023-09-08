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

function cdr2mask {
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}


get_network_no() {

    IFS=. read -r i1 i2 i3 i4 <<< ${1}

    mask=`cdr2mask ${2}`;

    IFS=. read -r m1 m2 m3 m4 <<< ${mask}
    printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"

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
    IFS="./" read -r ip1 ip2 ip3 ip4 N <<< "${CIDR}"

    # Convert IP address from quad notation to integer
    ip=$(($ip1 * 256 ** 3 + $ip2 * 256 ** 2 + $ip3 * 256 + $ip4))

    # Remove upper bits and check that all $N lower bits are 0
    if [ $ip1 -ge 0 ] && [ $ip1 -le 255 ] \
    && [ $ip2 -ge 0 ] && [ $ip2 -le 255 ] \
    && [ $ip3 -ge 0 ] && [ $ip3 -le 255 ] \
    && [ $ip4 -ge 0 ] && [ $ip4 -le 255 ] \
    && [ $N -ge 0 ] && [ $N -le 32 ]
    then
        ipaddr=${ip1}.${ip2}.${ip3}.${ip4}
        mask=`cdr2mask ${N}`;
        network=`get_network_no ${ipaddr} $N`;
        echo "${ipaddr}|${mask}|${N}|${network}"
        return 0
    else
        echo "IP address over range! [0.0.0.0/0-255.255.255.255/32]";
        return 1
    fi
}


# show interface
show_iface() {
    ip -br l show 2>/dev/null | awk '$0 !~ "lo|vir|wl|vnet|veth"{print $0}'
}

# declare map interfaces data
declare -A M_IFACE=()

# config interface
conf_iface() {
    let LAN_FLAG=0
    while true; do
        show_iface;
        if [ ${LAN_FLAG} -eq 0 ]; then
            read -p "Input WAN interface name or 'done': " iface
        else
            read -p "Input LAN${LAN_FLAG} interface name or 'done': " iface
        fi

        value=`ip -br l show ${iface} 2>/dev/null| awk '$0 !~ "lo|vir|wl|vnet|veth"{print $1}'`
        if [ "${value}" != "" ] && [ "${value}" == "${iface}" ]; then

            while true; do
                read -p "Input IP address [x.x.x.x/n]: " ipaddr
                result="$(valid_cidr ${ipaddr})|${LAN_FLAG}"

                if [ $? -ne 0 ]; then
                    echo "[${iface}] IP address error!, input again!"
                    continue;
                else
                    M_IFACE[${iface}]=${result}
                    break;
                fi
            done

            # Gateway & DNS
            if [ ${LAN_FLAG} -eq 0 ]; then

                M_IFACE["_wan"]="${iface}"
                while true; do
                    read -p "Input default gateway [x.x.x.x]: " gw
                    check_fmt_addr ${gw}
                    if [ $? -ne 0 ]; then
                        echo "IP address format error! exp: [10.0.0.1]"
                        continue;
                    else
                        M_IFACE["_wan"]="${M_IFACE["_wan"]}|${gw}"
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
                        M_IFACE["_wan"]="${M_IFACE["_wan"]}|${dns1}"
                        break;
                    fi
                done
                # M_IFACE["_wan"]="${gw}|${dns1}"
            fi
            let LAN_FLAG++
        elif [ "${iface}" == "done" ] || [ "${iface}" == "exit" ]; then
            break;
        else
            echo "Device [${iface}] does not exist, input again!"
        fi
    done

    printf "\n\n"
    # Note that we're stepping through KEYS here, not values.
    for key in ${!M_IFACE[@]}; do
        printf '"%s: %s"\n' "$key" "${M_IFACE[$key]}"
    done

}

# install packages
install_pkg() {
	apt update -y;
	apt install -y dnsmasq ifupdown nfs-common samba
	apt install -y net-tools tcpdump bridge-utils iptraf iftop openssl
	apt install -y unzip vim-tiny tree wget curl
}

# network setting
network_set() {
	# create interfaces directory
	mkdir -p ${ETC_DIR}/network/interfaces.d;
	mkdir -p ${ETC_DIR}/network/if-up.d/
	# ip address setting
	echo -e "source ${ETC_DIR}/network/interfaces.d/*\n" > ${ETC_DIR}/network/interfaces

	# loopback
	echo -e "# The loopback network interface\nauto lo\n\tiface lo inet loopback \n" > ${ETC_DIR}/network/interfaces.d/static.iface

	LAN_CFILE=""
	WAN_CFILE=""
	RUT_CFILE="#!/bin/sh"
    for k in ${!M_IFACE[@]}; do
		if [ "${k}" != "_wan" ]; then
			IFS="|" read -r addr mask mask_num network itype <<< ${M_IFACE[$k]}

			if [ ${itype} -eq 0 ]; then
				IFS="|" read -r ifwan gw dns1 <<< ${M_IFACE["_wan"]}

				WAN_CFILE="${WAN_CFILE}# The WAN network interface\n"
				WAN_CFILE="${WAN_CFILE}auto ${k}\n"
				WAN_CFILE="${WAN_CFILE}\tiface ${k} inet static\n"
				WAN_CFILE="${WAN_CFILE}\taddress ${addr}/${mask_num}\n"
				WAN_CFILE="${WAN_CFILE}\tgateway ${gw}\n"
				WAN_CFILE="${WAN_CFILE}\tdns-nameservers $dns1\n"
			else
				LAN_CFILE="${LAN_CFILE}# The LAN${itype} network interface\n"
				LAN_CFILE="${LAN_CFILE}auto ${k}\n"
				LAN_CFILE="${LAN_CFILE}\tiface ${k} inet static\n"
				LAN_CFILE="${LAN_CFILE}\taddress ${addr}/${mask_num}\n"
				if [ "${RUT_CFILE}" == "#!/bin/sh" ]; then
					RUT_CFILE="${RUT_CFILE}\n"
					RUT_CFILE="${RUT_CFILE}if [ \"\$IFACE\" = \"${k}\" ]; then\n"
				else
					RUT_CFILE="${RUT_CFILE}elif [ \"\$IFACE\" = \"${k}\" ]; then\n"
				fi
				RUT_CFILE="${RUT_CFILE}\t# ip route add ${network}/24 via XXX.XXX.XXX.XXX\n\treturn\n"
			fi
		fi
        # printf '"%s: %s"\n' "$key" "${M_IFACE[$key]}"
    done

	echo -e "${WAN_CFILE}" >> ${ETC_DIR}/network/interfaces.d/static.iface
	echo -e "${LAN_CFILE}" >> ${ETC_DIR}/network/interfaces.d/static.iface
	echo -e "${RUT_CFILE}fi" > ${ETC_DIR}/network/if-up.d/route
	chmod +x ${ETC_DIR}/network/if-up.d/route
}

# iptables setting
iptables_set() {
	# ip_forward
	echo "net.ipv4.ip_forward = 1" > ${ETC_DIR}/sysctl.conf && sysctl -p
	echo "net.ipv6.conf.all.forwarding = 1" >> ${ETC_DIR}/sysctl.conf && sysctl -p

	# get WAN iface info
	IFS="|" read -r ifwan gw dns1 <<< ${M_IFACE["_wan"]}

	# LAN interface
	iptables -t nat -A POSTROUTING -o ${ifwan} -j MASQUERADE

	# iptables save
	apt install -y iptables-persistent
}

# dnsmasq setting
dnsmasq_set() {

	# create dnsmasq directory
	mkdir -p ${ETC_DIR}/dnsmasq.d/;
    mkdir -p /var/log/dnsmasq/

	# dnsmasq dhcp
	DHCP_RANGE="listen-address=0.0.0.0,127.0.0.1
	resolv-file=/etc/dnsmasq.d/resolv.dnsmasq.conf
	log-facility=/var/log/dnsmasq/dnsmasq.log
	log-async=100
	conf-dir=/etc/dnsmasq.d\n";
	DNS_ADDRESS=""
    for k in ${!M_IFACE[@]}; do
		if [ "${k}" != "_wan" ]; then
			IFS="|" read -r addr mask mask_num network itype <<< ${M_IFACE[$k]}
			if [ ${itype} -ne 0 ]; then
				# dhcp-range=interface:eth1,192.168.2.128,192.168.2.254,24h
				DHCP_RANGE="${DHCP_RANGE}\tdhcp-range=interface:${k},0.0.0.0,255.255.255.255,48h\n"
				DNS_ADDRESS="${DNS_ADDRESS}address=/me.games.play/${addr}\n"
			fi
		fi
    done

	echo -e "${DHCP_RANGE}" > ${ETC_DIR}/dnsmasq.conf

	# dnsmasq address
	echo -e "${DNS_ADDRESS}" > ${ETC_DIR}/dnsmasq.d/address.conf

	# get WAN iface info
	IFS="|" read -r ifwan gw dns1 <<< ${M_IFACE["_wan"]}

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
}

# stop systemd server
stop_systemd() {
	mv ${ETC_DIR}/resolv.conf ${ETC_DIR}/resolv.conf.${DATE}

	# get WAN iface info
	IFS="|" read -r ifwan gw dns1 <<< ${M_IFACE["_wan"]}

	# dnsmasq resolv
	echo "nameserver ${dns1}" >> ${ETC_DIR}/resolv.conf
	systemctl disable --now systemd-resolved.service
	systemctl disable --now systemd-networkd.service
    systemctl disable --now systemd-networkd.socket
}

main() {
	echo "--------------start---------------"
	install_pkg;
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
	# start server
	start_server;
	# restart system
	reboot;
	echo "--------------finish---------------"
}

main;