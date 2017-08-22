<#
.SYNOPSIS
Get Server Information
.DESCRIPTION
This script will get the 

CPU specifications, 
memory size, 
OS configuration of version and 32/64 and service pack, 

the iis version, 
disk sizes, and more info on types of drive info like SSD (only if it supports or will throw an error you can ignore), 
version of SQL server,
and will run IIS at the end
.NOTES  

The script will execute the commands on multiple machines sequentially using non-concurrent sessions. This will process all servers from Serverlist.txt in the listed order.
The info will be exported to a csv format.
Requires: Serverlist.txt must be created in the same folder where the script is.
File Name  : get-server-info.ps1

This will create a csv file

#>


$executionpolicy = Get-ExecutionPolicy -Scope CurrentUser;
if ($executionpolicy -ne 'Unrestricted')
{
Set-ExecutionPolicy -Scope CurrentUser  -ExecutionPolicy 'Unrestricted';
}

Write-Host 'Press y and press enter using serverlist.txt (not supported yet)'
$uselocalhostonly =  Read-Host

if ($uselocalhostonly -eq 'y')
{

#Get the server list
$servers = Get-Content .\Serverlist.txt
}
else
{
$servers = "localhost"
}

Write-Host 'Press y and press enter for sql'
$hassql =  Read-Host
if ($hassql -eq 'y')
{
$hassql = $true;
}
else
{
$hassql = $false;
}



#Run the commands for each server in the list
$infoColl = @()
[string]$ConvertToGB = (1024 * 1024 * 1024)
[bool]$couldrunssd = $true;

function logerror()
{
	Write-Host 'Discovered Error';
	Write-Host $_.Exception.Message;
	Write-Host $_.Exception.ItemName;
}

# https://stackoverflow.com/questions/28731401/powershell-detect-if-drive-letter-is-mounted-on-a-ssd-solid-state-disk
Function GetDriveTypes()
# Returns an array of SSD drive letters - if any are found - assuming that the manufacturer inserted the letters SSD into the device name - which ultimately makes this method unreliable so beware to cross check using something like $DiskScore = (Get-WmiObject -Class Win32_WinSAT).DiskScore # Thanks to Rens Hollanders for this! http://renshollanders.nl/2013/01/sccm-mdt-identifying-ssds-from-your-task-sequence-by-windows-performance-index/
# http://stackoverflow.com/questions/28731401/powershell-detect-if-drive-letter-is-mounted-on-a-ssd-solid-state-disk/28731402#28731402
{
	try
	{
	  $hash = @{0='Unknown'; 3='HDD'; 4='SSD'; 5='SCM'};
	 $ssdresult = Get-WmiObject -namespace root\Microsoft\Windows\Storage MSFT_PhysicalDisk | Select-Object DeviceID,Model,@{LABEL='DriveType';EXPRESSION={$hash.item([int]$_.MediaType)}}   
	$couldrunssd = $true;
	 return $ssdresult;
	 }
	catch 
	{
		$couldrunssd = $false;
		if ($_.Exception.Message -ne '')
		{
		logerror;
			return '';
		}
	}
}
$ssd = GetDriveTypes;

Foreach ($s in $servers)
{
	$CPUInfo = Get-WmiObject Win32_Processor -ComputerName $s #Get CPU Information
	$OSInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $s #Get OS Information
	#Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal.
	$OSTotalVirtualMemory = [math]::round($OSInfo.TotalVirtualMemorySize / 1MB, 2)
	$OSTotalVisibleMemory = [math]::round(($OSInfo.TotalVisibleMemorySize / 1MB), 2)
	$PhysicalMemory = Get-WmiObject CIM_PhysicalMemory -ComputerName $s | Measure-Object -Property capacity -Sum | % { [Math]::Round(($_.sum / 1GB), 2) }

	$iisversion = get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\  | select setupstring,versionstring

	Foreach ($CPU in $CPUInfo)
	{
		$infoObject = New-Object PSObject
		#The following add data to the infoObjects.	
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "ServerName" -value $CPU.SystemName
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "Processor" -value $CPU.Name
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "Model" -value $CPU.Description
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "Manufacturer" -value $CPU.Manufacturer
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "PhysicalCores" -value $CPU.NumberOfCores
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_L2CacheSize" -value $CPU.L2CacheSize
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "CPU_L3CacheSize" -value $CPU.L3CacheSize
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "Sockets" -value $CPU.SocketDesignation
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "LogicalCores" -value $CPU.NumberOfLogicalProcessors
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Name" -value $OSInfo.Caption
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Version" -value $OSInfo.Version
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "Service Pack" -value $OSInfo.ServicePackMajorVersion

		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalPhysical_Memory_GB" -value $PhysicalMemory
	#	Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalVirtual_Memory_MB" -value $OSTotalVirtualMemory
	#	Add-Member -inputObject $infoObject -memberType NoteProperty -name "TotalVisable_Memory_MB" -value $OSTotalVisibleMemory
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "IIS_Version" -value $iisversion.VersionString 


		$os_type = (Get-WmiObject -Class Win32_ComputerSystem).SystemType -match ‘(x64)’

		if ($os_type -eq "True") {
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Type" -value '64'
		}
		else {
		$os_type = (Get-WmiObject -Class Win32_ComputerSystem).SystemType -match ‘(x86)’

		if ($os_type -eq "True") {
			Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Type" -value '32'
		}
		}
		}

	Foreach($disk in Get-WmiObject Win32_logicaldisk)
	{
	[double] $size =  [Math]::Round( $($disk.Size / $ConvertToGB),2);
			Add-Member -inputObject $infoObject -memberType NoteProperty -name $($disk.DeviceID+"TotalDisk (GB)") -value $($size);
			[double] $freespace = [Math]::Round($disk.Freespace / $ConvertToGB,2);	
			Add-Member -inputObject $infoObject -memberType NoteProperty -name $($disk.DeviceID+"FreeDisk  (GB)") -value $($freespace);
	[double] $onepercent = $size / 100.0;

			[double] $diskremaining = [Math]::Round($freespace / $onepercent,2);
					Add-Member -inputObject $infoObject -memberType NoteProperty -name $($disk.DeviceID+"Percentage_diskspace_remaining") -value $($diskremaining);
	}

	
	if ($couldrunssd -eq $true)
	{
		Write-Host 'Drive types detected';
		Foreach($drivetype in $ssd)
		{
			[string]$type=	$ssd.DeviceID+' ' +$ssd.Model+' '+$ssd.DriveType;
			Add-Member -inputObject $infoObject -memberType NoteProperty -name "DriveInfo" -value $($type);
			#show it out to the user
			$type;
		}
	}
	else
	{
		Write-Host 'Could not detect drives - likely a really old computer or pc'
	}
#	Write-Host 'checking for sql (if this is not here there will be a 5 second delay)'
	if ($hassql -eq $true)
	{
		$sqlserver = $(Invoke-SqlCmd -query "select @@version" -ServerInstance "localhost").Column1
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "SQL Server" -value $($sqlserver);

	}

	$infoObject #Output to the screen for a visual feedback.

		$infoColl += $infoObject

}

$infoColl | Export-Csv -path .\Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation #Export the results in csv file.

if ($executionpolicy -ne 'Unrestricted')
{
Set-ExecutionPolicy -Scope CurrentUser  -ExecutionPolicy $executionpolicy
}

Write-Host 'Run IIS? Press y and press enter '
$runIIS=  Read-Host
if ($runIIS -eq "y")
{
Start-Process -FilePath $([System.Environment]::ExpandEnvironmentVariables("%WINDIR%") + '\system32\inetsrv\InetMgr.exe')
}