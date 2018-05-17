#!/bin/sh
# Author: William Lam
# Contact: @lamw
# Description: Tested on ESXi 6.5 Update 2 & 6.7

set -x
exec 2>/ic-customization.log

echo -e "\n=== Start Pre-Freeze ==="

# Disable VSAN traffic if enabled & vmnic0
echo "Disabling vmnic0 ..."
esxcli vsan network remove -i vmk0
esxcli network nic down -n vmnic0

# Stop hostd
echo "Stopping hostd ..."
/etc/init.d/hostd stop

# Remove any exisitng VMkernel interfaces which would have associationg with existing MAC Addresses
echo "Removing vmk0 interface ..."
localcli network ip interface set -e false -i vmk0
localcli network ip interface remove -i vmk0
localcli network vswitch standard portgroup remove -p "Management Network" -v "vSwitch0"

# Ensure the new MAC Address is automatically picked up once cloned
echo "Enable MAC Address updates ..."
localcli system settings advanced set -o /Net/FollowHardwareMac -i 1

# Remove any potential old DHCP leases
echo "Clearing DHCP leases ..."
rm -f /etc/dhclient*leases

# Ensure new system UUID is generated
echo "Clearing UUID ..."
sed -i 's#/system/uuid.*##g' /etc/vmware/esx.conf

echo -e "=== End of Pre-Freeze ===\n"

echo -e "Freezing ...\n"

vmtoolsd --cmd "instantclone.freeze"

echo -e "\n=== Start Post-Freeze ==="

# retrieve VM customization info passed from vSphere API
HOSTNAME=$(vmtoolsd --cmd "info-get guestinfo.ic.hostname")
IP_ADDRESS=$(vmtoolsd --cmd "info-get guestinfo.ic.ipaddress")
NETMASK=$(vmtoolsd --cmd "info-get guestinfo.ic.netmask")
GATEWAY=$(vmtoolsd --cmd "info-get guestinfo.ic.gateway")
DNS=$(vmtoolsd --cmd "info-get guestinfo.ic.dns")
NETWORK_TYPE=$(vmtoolsd --cmd "info-get guestinfo.ic.networktype")
UUID=$(vmtoolsd --cmd "info-get guestinfo.ic.uuid")
UUIDHEX=$(vmtoolsd --cmd "info-get guestinfo.ic.uuidhex")

# Updating ESXi Host UUID
echo "Updating ESXi Host UUID ..."
vsish -e set /system/systemUuid ${UUIDHEX}
echo "/system/uuid = \"${UUID}\"" >> /etc/vmware/esx.conf

# Updating VSAN Node UUID to match Host UUID
echo "Updating VSAN Node UUID ..."
localcli system settings advanced set -o /VSAN/NodeUuid -s ${UUID}

# setup vmk0
echo "Configuring Management Network (vmk0) ..."
localcli network nic up -n vmnic0
localcli network vswitch standard portgroup add -p "Management Network" -v "vSwitch0"
localcli network ip interface add -i vmk0 -p "Management Network"
if [ ${NETWORK_TYPE} == "static" ]; then
    localcli network ip interface ipv4 set -i vmk0 -I ${IP_ADDRESS} -N ${NETMASK} -t static
else
    localcli network ip interface ipv4 set -i vmk0 -t dhcp
fi
localcli system hostname set -f ${HOSTNAME}
if [ ${TYPE} == "static" ]; then
    localcli network ip route ipv4 add -g ${GATEWAY} -n default
fi

# Start hostd
echo "Starting hostd ..."
/etc/init.d/hostd start &

echo "Wait for hostd to be ready & then rescan storage adapter ..."
# Ensure hostd is ready
while ! vim-cmd hostsvc/hostsummary > /dev/null; do
sleep 15
done
esxcli storage core adapter rescan -a
esxcli vsan network ip add -i vmk0
echo "=== End of Post-Freeze ==="

echo -e "\nCheck /root/ic-customization.log for details\n\n"
