<#
.SYNOPSIS Script to deploy VCHA using Instant Clone (Proof of Concept, not officially supported)
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
#>

Import-Module .\InstantClone.psm1

$SourceVCSAName = "VCSA-Active"
$SourceVCSAAddress = "10.20.120.25"
$SourceVCSAVIUsername = "administrator@vsphere.local"
$SourceVCSAVIPassword = "VMware1!"
$SourceVCSAOSUsername = "root"
$SourceVCSAOSPassword = "VMware1!"

$VCAHANetworkName = "Private"
$SourceVCSAHAIpAddress = "172.30.0.25"
$PassiveVCSAName = "VCSA-Passive"
$PassiveVCSAHAIpAddress = "172.30.0.26"
$WitnessVCSAName = "VCSA-Witness"
$WitnessVCSAHAIpAddress = "172.30.0.27"
$VCSANetworkmask = "255.255.255.0" # API expects netmask format
$VCSANetworkPrefix = "24" # PhotonOS expects CIDR format

### DO NOT EDIT BEYOND HERE ###

$StartTime = Get-Date
Write-Host -ForegroundColor Cyan "Starting VCHA Instant Clone ..."

$vm = Get-VM -Name $SourceVCSAName

# Add second NIC and configure for VCHA network
Write-Host -ForegroundColor Cyan "Adding eth1 to $SourceVCSAAddress for VCHA Network ..."
New-NetworkAdapter -VM $vm -Portgroup (Get-VirtualPortGroup -Name $VCAHANetworkName) -StartConnected -Type Vmxnet3 -Confirm:$false | Out-Null

# Configure Second NIC for VCHA network
Write-Host -ForegroundColor Cyan "Configuring eth1 for VCHA Network ..."

$vchaCisService = Connect-CisServer -Server $SourceVCSAAddress -User $SourceVCSAVIUsername -Password $SourceVCSAVIPassword | Out-Null
$ipv4NetworkSerice = Get-CisService com.vmware.appliance.networking.interfaces.ipv4
$networkConfig = $ipv4NetworkSerice.Help.set.config.Create()
$networkConfig.mode = "STATIC"
$networkConfig.address = $SourceVCSAHAIpAddress
$networkConfig.prefix = $VCSANetworkPrefix
$ipv4NetworkSerice.set("nic1",$networkConfig)
Disconnect-CisServer * -Confirm:$false  | Out-Null

# Prepare for VCHA
$vchaVIConnection = Connect-VIServer -Server $SourceVCSAAddress -User $SourceVCSAVIUsername -Password $SourceVCSAVIPassword 
$vcHAClusterConfig = Get-View -Server $vchaVIConnection failoverClusterConfigurator
$vchaNetworkSpec = New-Object VMware.Vim.VchaClusterNetworkSpec

$passiveNetworkSpec = New-Object VMware.Vim.PassiveNodeNetworkSpec
$passiveIpSettings = New-Object VMware.Vim.CustomizationIPSettings
$fixedIp = New-object VMware.Vim.CustomizationFixedIp
$fixedIp.IpAddress = $PassiveVCSAHAIpAddress
$passiveIpSettings.Ip = $fixedIp
$passiveIpSettings.SubnetMask = $VCSANetworkmask
$passiveNetworkSpec.IpSettings = $passiveIpSettings
$vchaNetworkSpec.PassiveNetworkSpec = $passiveNetworkSpec

$witnessNetworkSpec = New-Object VMware.Vim.NodeNetworkSpec
$witnessIpSettings = New-Object VMware.Vim.CustomizationIPSettings
$fixedIp = New-object VMware.Vim.CustomizationFixedIp
$fixedIp.IpAddress = $WitnessVCSAHAIpAddress
$witnessIpSettings.Ip = $fixedIp
$witnessIpSettings.SubnetMask = $VCSANetworkmask
$witnessNetworkSpec.IpSettings = $witnessIpSettings
$vchaNetworkSpec.WitnessNetworkSpec = $witnessNetworkSpec

Write-Host -ForegroundColor Cyan "Preparing VCHA on $SourceVCSAAddress ..."
$vcHAClusterConfig.prepareVcha($vchaNetworkSpec)

# Instant Clone Passive & Witness
New-InstantClone -SourceVM $SourceVCSAName -DestinationVM $PassiveVCSAName -CustomizationFields @{"guestinfo.ic.sourcevc"="$SourceVCSAName";"guestinfo.ic.ipaddress"="$PassiveVCSAHAIpAddress";"guestinfo.ic.prefix"="$VCSANetworkPrefix"}
New-InstantClone -SourceVM $SourceVCSAName -DestinationVM $WitnessVCSAName -CustomizationFields @{"guestinfo.ic.sourcevc"="$SourceVCSAName";"guestinfo.ic.ipaddress"="$WitnessVCSAHAIpAddress";"guestinfo.ic.prefix"="$VCSANetworkPrefix"}

# Refresh MAC Address + Configure VCHA IP for Passive & Witness
Write-Host -ForegroundColor Cyan "Running customization script /root/customize.sh on Passive VCSA ..."
Invoke-VMScript -VM (Get-VM -Name $PassiveVCSAName) -ScriptText "/root/customize.sh" -ScriptType Bash -GuestUser $SourceVCSAOSUsername  -GuestPassword $SourceVCSAOSPassword | Out-Null

Write-Host -ForegroundColor Cyan "Running customization script /root/customize.sh on Witness VCSA ..."
Invoke-VMScript -VM (Get-VM -Name $WitnessVCSAName) -ScriptText "/root/customize.sh" -ScriptType Bash -GuestUser $SourceVCSAOSUsername  -GuestPassword $SourceVCSAOSPassword | Out-Null

# Connecting eth1 for Passive & Witness 
Write-Host -ForegroundColor Cyan "Connecting eth1 on Passive VCSA .."
Get-VM -Name $PassiveVCSAName | Get-NetworkAdapter | where {$_.Name -eq "Network adapter 2"} | Set-NetworkAdapter -Connected $true -Confirm:$false | Out-Null

Write-Host -ForegroundColor Cyan "Connecting eth1 on Witness VCSA .."
Get-VM -Name $WitnessVCSAName | Get-NetworkAdapter | where {$_.Name -eq "Network adapter 2"} | Set-NetworkAdapter -Connected $true -Confirm:$false | Out-Null

# Configure VCHA
$vcHAClusterConfig = Get-View -Server $vchaVIConnection failoverClusterConfigurator

$vchaConfigSpec = New-Object VMware.Vim.VchaClusterConfigSpec
$vchaConfigSpec.PassiveIp = $PassiveVCSAHAIpAddress
$vchaConfigSpec.WitnessIp = $WitnessVCSAHAIpAddress

Write-Host -ForegroundColor Cyan "Configuring VCHA on $SourceVCSAAddress ...`n"
$task = $vcHAClusterConfig.configureVcha_Task($vchaConfigSpec)
$task1 = Get-Task -Id ("Task-$($task.value)")
$task1 | Wait-Task

# Profit
Disconnect-VIServer -Server $vchaVIConnection -Confirm:$false

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)
Write-Host -ForegroundColor Cyan  "`nStartTime: $StartTime"
Write-Host -ForegroundColor Cyan  "  EndTime: $EndTime"
Write-Host -ForegroundColor Green " Duration: $duration minutes"