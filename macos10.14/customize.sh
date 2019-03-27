#!/bin/bash
# Author: William Lam
# Contact: @lamw
# Description: Tested on MacOS 10.14.14 (Mojave)

set -x
exec 2>/Users/virtuallyghetto/Desktop/ic-customization.log

echo -e "\n=== Start Pre-Freeze ==="

# Disable primary network interface by unloading kernel moduile
# Credit goes to https://github.com/mjm for sharing tidbit
echo "Disabling Network Interface"
kextunload /System/Library/Extensions/IONetworkingFamily.kext/Contents/PlugIns/Intel82574L.kext
sleep 2

echo -e "=== End of Pre-Freeze ===\n"

echo -e "Freezing ...\n"

/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd="instantclone.freeze"

echo -e "\n=== Start Post-Freeze ==="

# Retrieve VM customization info passed from vSphere API
HOSTNAME=$(/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd "info-get guestinfo.ic.hostname")
IP_ADDRESS=$(/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd "info-get guestinfo.ic.ipaddress")
NETMASK=$(/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd "info-get guestinfo.ic.netmask")
GATEWAY=$(/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd "info-get guestinfo.ic.gateway")
DNS=$(/Library/Application\ Support/VMware\ Tools/vmware-tools-daemon --cmd "info-get guestinfo.ic.dns")

echo "Re-enabling Network Interface"
kextload /System/Library/Extensions/IONetworkingFamily.kext/Contents/PlugIns/Intel82574L.kext

# Static Network Assignment
# https://discussions.apple.com/thread/5082299?answerId=5082299021#5082299021
if [[ ! -z ${HOSTNAME} && ! -z ${IP_ADDRESS} && ! -z ${NETMASK} && ! -z ${GATEWAY} && ! -z ${DNS} ]]; then
    ETH0_INTERFACE_NAME="Ethernet"

    echo "Configuring Hostname to ${HOSTNAME} ..."
    networksetup -setcomputername ${HOSTNAME}

    echo "Configuring Static IP Address ..."
    networksetup -setmanual ${ETH0_INTERFACE_NAME} ${IP_ADDRESS} ${NETMASK} ${GATEWAY}

    echo "Configuring DNS Server ..."
    networksetup -setdnsservers ${ETH0_INTERFACE_NAME} ${DNS}
fi

echo "=== End of Post-Freeze ==="

echo -e "\nCheck /root/ic-customization.log for details\n\n"