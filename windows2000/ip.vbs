Set args = Wscript.Arguments

ip=WScript.Arguments.Item(0)
netmask=WScript.Arguments.Item(1)
gateway=WScript.Arguments.Item(2)
dns=WScript.Arguments.Item(3)
hostname=WScript.Arguments.Item(4)

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colNetAdapters = objWMIService.ExecQuery _
    ("Select * from Win32_NetworkAdapterConfiguration where IPEnabled=TRUE")

strIPAddress = Array(ip)
strSubnetMask = Array(netmask)
strGateway = Array(gateway)
arrDNSServers = Array(dns)
strGatewayMetric = Array(1)

WScript.Echo ""
WScript.Echo "Applying new Network configurations ..."
WScript.Echo ""
For Each objNetAdapter in colNetAdapters
    errEnable = objNetAdapter.EnableStatic(strIPAddress, strSubnetMask)
    errGateways = objNetAdapter.SetGateways(strGateway, strGatewaymetric)
    errDNS = objNetAdapter.SetDNSServerSearchOrder(arrDNSServers)
    If errEnable = 0 Then
        WScript.Echo "The IP address has been changed."
    Else
        WScript.Echo "The IP address could not be changed."
    End If
Next

WScript.Echo ""
WScript.Echo "Updating Hostname ..."

Set oShell = CreateObject ("WSCript.shell" )

sCCS = "HKLM\SYSTEM\CurrentControlSet\"
sTcpipParamsRegPath = sCCS & "Services\Tcpip\Parameters\"
sCompNameRegPath = sCCS & "Control\ComputerName\"

With oShell
.RegDelete sTcpipParamsRegPath & "Hostname"
.RegDelete sTcpipParamsRegPath & "NV Hostname"

.RegWrite sCompNameRegPath & "ComputerName\ComputerName", hostname
.RegWrite sCompNameRegPath & "ActiveComputerName\ComputerName", hostname
.RegWrite sTcpipParamsRegPath & "Hostname", hostname
.RegWrite sTcpipParamsRegPath & "NV Hostname", hostname
End With ' oShell