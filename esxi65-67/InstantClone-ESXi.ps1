<#
.SYNOPSIS Script to deploy Nested ESXi Instasnt Clones
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Reference: http://www.virtuallyghetto.com/2018/05/leveraging-instant-clone-in-vsphere-6-7-for-extremely-fast-nested-esxi-provisioning.html
#>

Import-Module InstantClone.psm1

$SourceVM = "Nested_ESXi6.7_Appliance_Template"

$numOfVMs = 3

$ipNetwork = "192.168.30"
$ipStartingCount=50
$netmask = "255.255.255.0"
$dns = "192.168.30.1"
$gw = "192.168.30.1"
$networktype = "static" # static or dhcp

### DO NOT EDIT BEYOND HERE ###

$StartTime = Get-Date
Write-host ""
foreach ($i in 1..$numOfVMs) {
    $newVMName = "esxi-0$i"

    # Generate random UUID which will be used to update
    # ESXi Host & VSAN Node UUID
    $uuid = [guid]::NewGuid()
    # Changing ESXi Host UUID requires format to be in hex
    $uuidHex = ($uuid.ToByteArray() | %{"0x{0:x}" -f $_}) -join " "

    $guestCustomizationValues = @{
        "guestinfo.ic.hostname" = "$newVMName"
        "guestinfo.ic.ipaddress" = "$ipNetwork.$ipStartingCount"
        "guestinfo.ic.netmask" = "$netmask"
        "guestinfo.ic.gateway" = "$gw"
        "guestinfo.ic.dns" = "$dns"
        "guestinfo.ic.sourcevm" = "$SourceVM"
        "guestinfo.ic.networktype" = "$networktype"
        "guestinfo.ic.uuid" = "$uuid"
        "guestinfo.ic.uuidHex" = "$uuidHex"
    }
    $ipStartingCount++

    # Create Instant Clone
    New-InstantClone -SourceVM $SourceVM -DestinationVM $newVMName -CustomizationFields $guestCustomizationValues

    # Retrieve newly created Instant Clone
    $VM = Get-VM -Name $newVMName

    # Hot Add 2 VMDKs for use w/VSAN
    Write-Host "`tHot-Add 4 & 8 GB VMDK for use with VSAN"
    New-HardDisk -VM $VM -CapacityGB 4 -StorageFormat Thin -Confirm:$false | Out-Null
    New-HardDisk -VM $VM -CapacityGB 8 -StorageFormat Thin -Confirm:$false | Out-Null
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

Write-Host -ForegroundColor Cyan  "`nTotal Instant Clones: $numOfVMs"
Write-Host -ForegroundColor Cyan  "StartTime: $StartTime"
Write-Host -ForegroundColor Cyan  "  EndTime: $EndTime"
Write-Host -ForegroundColor Green " Duration: $duration minutes"