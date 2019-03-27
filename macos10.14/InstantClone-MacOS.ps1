# William Lam
# www.virtuallyghetto.com
# Script to deploy MacOS 10.14 (Mojave) Instant Clones

$SourceVM = "MacOS-Mojave-Template"

$numOfVMs = 5
$ipNetwork = "192.168.30"
$ipStartingCount=50
$netmask = "255.255.255.0"
$dns = "192.168.30.1"
$gw = "192.168.30.1"

### DO NOT EDIT BEYOND HERE ###

if ( ! (Get-VM -Name $SourceVM).ExtensionData.Summary.Runtime.InstantCloneFrozen ) {
    Write-Host -ForegroundColor "`n$($SourceVM) has not gone into frozen state yet, please try again in a moment`n"
    break
}

If ( ! (Get-module InstantClone )) {
    Write-Host -ForegroundColor Red "`nInstant Clone Module not loaded`n"
    break
}

$StartTime = Get-Date
Write-host ""
foreach ($i in 1..$numOfVMs) {
    $newVMName = "MacOS-Mojave-IC-$i"

    $guestCustomizationValues = @{
        "guestinfo.ic.hostname" = "$newVMName"
        "guestinfo.ic.ipaddress" = "$ipNetwork.$ipStartingCount"
        "guestinfo.ic.netmask" = "$netmask"
        "guestinfo.ic.gateway" = "$gw"
        "guestinfo.ic.dns" = "$dns"
    }
    $ipStartingCount++
    New-InstantClone -SourceVM $SourceVM -DestinationVM $newVMName -CustomizationFields $guestCustomizationValues
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

Write-Host -ForegroundColor Cyan  "`nTotal Instant Clones: $numOfVMs"
Write-Host -ForegroundColor Cyan  "StartTime: $StartTime"
Write-Host -ForegroundColor Cyan  "  EndTime: $EndTime"
Write-Host -ForegroundColor Green " Duration: $duration minutes"