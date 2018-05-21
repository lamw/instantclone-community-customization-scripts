#!/bin/bash
# Author: William Lam
# Contact: @lamw
# Description: Tested on VCSA 6.7

set -x
exec 2>/root/ic-customization.log

# retrieve VM customization info passed from vSphere API
IP_ADDRESS=$(vmware-rpctool "info-get guestinfo.ic.ipaddress")
PREFIX=$(vmware-rpctool "info-get guestinfo.ic.prefix")

echo "Updating IP Address for eth1 ..."
sed -i "s#Address.*#Address=${IP_ADDRESS}/${PREFIX}#g" /etc/systemd/network/10-eth1.network

# bring down both eth0 and eth1
echo "Bringing down eth0 and eth1 ..."
ifdown eth0
ifdown eth1

echo "Updating MAC Address ..."
for NETDEV in /sys/class/net/e*
do
	DEVICE_LABEL=$(basename $(readlink -f "$NETDEV/device"))
	DEVICE_DRIVER=$(basename $(readlink -f "$NETDEV/device/driver"))
	echo $DEVICE_LABEL > /sys/bus/pci/drivers/$DEVICE_DRIVER/unbind
	echo $DEVICE_LABEL > /sys/bus/pci/drivers/$DEVICE_DRIVER/bind
done

echo "Bringing up eth1 ..."
ifup eth1

echo -e "\nCheck /root/ic-customization.log for details\n\n"