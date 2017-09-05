#
# getdb.ps1
#

#=================================================================================
# Designed to deploy a database from a dacpac
#
# Usage:
# .\sqlPackageDeploymentCMD.ps1  -targetServer "LOCALHOST" -targetDB "IamADatabase" -sourceFile "C:\ProjectDirectory\bin\Debug\IamADatabase.dacpac" -SQLCMDVariable1 "IamASQLCMDVariableValue"
# 
# So, why would you do this when you could just call the sqlpackage.exe directly? 
# Because Powershell provides a higher level of orchestration; I plan to call this script from another script that 
# first calls a script to build the dacpac that is then used in this script.
#=================================================================================

[CmdletBinding()]
Param(
    
    #SQLPackage
    # This directory for sqlpackage is specific to SQL Server 2012 (v11).
    [Parameter(Mandatory=$false)]
 #   [string]$sqlPackageFileName = "C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\sqlpackage.exe",
[string]$sqlPackageFileName = "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\sqlpackage.exe",
   
    #Database connection
    [Parameter(Mandatory=$false)]
    [string]$targetServerName = "127.0.0.1\sql2016,1433",
    [Parameter(Mandatory=$false)]
    [string]$sourceDBName = "a",

	[Parameter(Mandatory=$false)]
    [string]$destinationDBname = "b",

    #DacPac source
    #Note PSScriptRoot is the location where this script is called from. Good idea to keep it in the root of 
    # your solution then the absolute path is easy to reconstruct
    [Parameter(Mandatory=$false)]
    [string]$targetFile = """$PSScriptRoot\""", #Quotes in case your path has spaces

    #SQLCMD variables
    [Parameter(Mandatory=$false)]
    [string]$username = "sa",

    [Parameter(Mandatory=$false)]
    [string]$password = "12345"



)

Clear-Host;

# in reality these three lines would not exist
$mydatetime = [System.DateTime]::Now;
$inserttest = "insert into info (data) values ('$mydatetime')";
$inserttest;
$data = Invoke-sqlcmd -Query $inserttest -ServerInstance $targetServerName -Database $sourceDBName -Username $username -Password $password;


$source = $("""$PSScriptRoot\$sourceDBName.bacpac""")

& "$sqlPackageFileName" `
/Action:Export `
/tf:$source `
/ssn:tcp:$targetServerName `
/sdn:$sourceDBName `
/su:$username /sp:$password `
 /p:Storage=File;

 #export second database

 <#
$destination = $("""$PSScriptRoot\$destinationDBname.dacpac""")

  & "$sqlPackageFileName" `
/Action:Extract `
/tf:$destination  `
/ssn:tcp:$targetServerName `
/sdn:$destinationDBname `
/su:$username /sp:$password `
 /p:Storage=File;
  #>

 # https://social.msdn.microsoft.com/Forums/sqlserver/en-US/4611e5e4-9d02-4ea0-8262-733d36dac201/using-sqlpackage-to-create-differential-script?forum=ssdt

 # generate a different script
 #sqlpackage /a:Script 
 #/sf:"source.dacpac" 
 #/tf:"C:\destinatino.dacpac" /tdn:"Database54" /op:"C:\diffscript.txt"
 Write-Host ''
  $destinationfile = $("""$PSScriptRoot\diffscript.dacpac""")
 # get the difference between databases
 & "$sqlPackageFileName" `
/Action:script `
/sf:$source  `
/tsn:tcp:$targetServerName  `
/tdn:$destinationDBname `
/su:$username /sp:$password `
/op:$destinationfile
 


 # apply source to destination


#/V:SQLCMDVariable1=$SQLCMDVariable1 ` #If your project includes other database references, or pre/post deployment scripts uses SQLCMD variables
#/v:SQLCMDVariable2=$SQLCMDVariable2 `