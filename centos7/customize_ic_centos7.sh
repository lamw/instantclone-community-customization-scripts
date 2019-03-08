#!/bin/bash
#(C) Copyright 2019 Hewlett Packard Enterprise Development LP.
# Author: Russell Briggs (github: briggr1)
# Instant Clone Pre Customization Script
# OS: CentOS Linux release 7.6.1810 (Core)

set -x
touch /root/ic-customization.log
exec > /root/ic-customization.log 2>&1

echo -e "\n=== Start Pre-Freeze ==="

# Disable ens192
echo "Disabling ens192 interface ..."
mv /etc/sysconfig/network-scripts/ifcfg-ens192 /etc/sysconfig/network-scripts/ifcfg-ens192.bak
ip link set ens192 down

echo -e "=== End of Pre-Freeze ===\n"

echo -e "Freezing ...\n"

vmware-rpctool "instantclone.freeze"

######################################################
# All commands past this point are run on the clones
######################################################

echo -e "\n=== Start Post-Freeze ==="
# retrieve networking info passed from script
HOSTNAME=$(vmware-rpctool "info-get guestinfo.ic.hostname")
IPV4=$(vmware-rpctool "info-get guestinfo.ic.ipv4")
NETMASK=$(vmware-rpctool "info-get guestinfo.ic.netmask")
GATEWAY=$(vmware-rpctool "info-get guestinfo.ic.gateway")
DNS=$(vmware-rpctool "info-get guestinfo.ic.dns")

echo "Updating MAC Address ..."
if lsmod | grep vmxnet3 > /dev/null 2>&1 ; then
        NIC_MODULE=vmxnet3
elif lsmod | grep e1000e > /dev/null 2>&1 ; then
        NIC_MODULE=e1000e
elif lsmod | grep e1000 > /dev/null 2>&1 ; then
        NIC_MODULE=e1000
fi
modprobe -r ${NIC_MODULE};modprobe ${NIC_MODULE}

sleep 5   # 

UUID=`uuidgen ens192`
ENS192MAC=`cat /sys/class/net/ens192/address`

echo "Updating IP Address ..."
cat > /etc/sysconfig/network-scripts/ifcfg-ens192 << CENTOS_NET
HWADDR=${ENS192MAC}
NM_CONTROLLED="no"
ONBOOT=yes
BOOTPROTO=static
IPADDR=${IPV4}
NETMASK=${NETMASK}
GATEWAY=${GATEWAY}
DNS1=${DNS}
DEFROUTE=yes
IPV6INIT=no
NAME=ens192
UUID=${UUID}
DEVICE=ens192
HOSTNAME=${HOSTNAME}
CENTOS_NET

chmod 777 /etc/sysconfig/network-scripts/ifcfg-ens192

echo "Enabling ens192 interface ..."
ip link set ens192 up

echo "Updating Hostname ..."
hostnamectl set-hostname ${HOSTNAME}

echo "Enabling networking ..."
systemctl restart network

echo "Updating Hardware Clock on the system ..."
hwclock --hctosys

echo "=== End of Post-Freeze ==="