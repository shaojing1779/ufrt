#!/bin/sh

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
    # if [ $(($ip % 2**(32-$N))) = 0 ]
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

# read -p "Input Ip Address with x.x.x.x/n: " ipaddr
# valid_cidr ${ipaddr};
# valid_cidr ${1};

# read -p "Do you understand this script? "
#
# while true; do
#     read -p "Add network interface?: [Y/n] " yn
#     case ${yn} in
#     [Yy]*|'' ) echo "YES!";
#         read -p "Input IP address [x.x.x.x/n]: " ipaddr
#         valid_cidr ${ipaddr};
#         break;;
#     [Nn]* ) echo "NO!"; break;;
#     * ) echo "Please answer yes or no.";;
#     esac
# done

# show interface
show_iface() {
    ip -br l show 2>/dev/null | awk -F"[ ]" '$0 !~ "lo|vir|wl|vnet"{print $0;getline}'
}

# DR_NETWORK DR_IPADDR DR_MASK_STR DR_MASK_NUM TYPE
# setting interface
each_iface() {
    let LAN_FLAG=0
    declare -A M_IFACE=()
    while true; do
        show_iface;
        if [ ${LAN_FLAG} -eq 0 ]; then
            read -p "Input WAN interface name or 'done': " iface
        else
            read -p "Input LAN${LAN_FLAG} interface name or 'done': " iface
        fi

        value=`ip -br l show ${iface} 2>/dev/null| awk -F"[ ]" '$0 !~ "lo|vir|wl|vnet"{print $1;getline}'`
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

                M_IFACE["_wan"]="_wan"
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

each_iface;
