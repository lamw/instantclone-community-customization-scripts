@echo off
pushd %~dp0

echo(
echo vGhetto Instant Clone Customization - Microsoft Windows 2000

cscript /nologo nic.vbs

echo(
echo Freezing ...
"C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "instantclone.freeze"

echo(
echo Resumed from freeze ...
echo(

set ipcmd=""C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "info-get guestinfo.ic.ipaddress""

FOR /F "tokens=*" %%i IN (' %ipcmd% ') DO SET IP=%%i

set netmaskcmd=""C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "info-get guestinfo.ic.netmask""

FOR /F "tokens=*" %%i IN (' %netmaskcmd% ') DO SET NETMASK=%%i

set gatewaycmd=""C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "info-get guestinfo.ic.gateway""

FOR /F "tokens=*" %%i IN (' %gatewaycmd% ') DO SET GATEWAY=%%i

set dnscmd=""C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "info-get guestinfo.ic.dns""

FOR /F "tokens=*" %%i IN (' %dnscmd% ') DO SET DNS=%%i

set hostnamecmd=""C:\Program Files\VMware\VMware Tools\vmtoolsd.exe" --cmd "info-get guestinfo.ic.hostname""

FOR /F "tokens=*" %%i IN (' %hostnamecmd% ') DO SET HOSTNAME=%%i

cscript /nologo nic.vbs
ping 1.1.1.1 -n 1 -w 1000>nul

cscript /nologo ip.vbs %IP% %NETMASK% %GATEWAY% %DNS% %HOSTNAME%