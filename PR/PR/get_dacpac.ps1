#
# get_dacpac.ps1
#
#
# Extract DACPACs from all databases
#
# Author: Gianluca Sartori - @spaghettidba
# Date:   2013/02/13
# Purpose:
# Loop through all user databases and extract
# a DACPAC file in the working directory
#
#
 

# needs - https://docs.microsoft.com/en-us/sql/ssdt/download-sql-server-data-tools-ssdt

Param(
    [Parameter(Position=0,Mandatory=$true)]
    [string]$ServerName
)
 
cls
 
try {
    if((Get-PSSnapin -Name SQlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null){
        Add-PSSnapin SQlServerCmdletSnapin100
    }
}
catch {
    Write-Error "This script requires the SQLServerCmdletSnapIn100 snapin"
    exit
}
 
#
# Gather working directory (script path)
#
$script_path = Split-Path -Parent $MyInvocation.MyCommand.Definition
 
$sql = "
    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb','distribution')
"
 
$data = Invoke-sqlcmd -Query $sql -ServerInstance $ServerName -Database master
 
$data | ForEach-Object {
 
    $DatabaseName = $_.name
 
    #
    # Run sqlpackage
    #
    &"C:\Program Files (x86)\Microsoft SQL Server\110\DAC\bin\sqlpackage.exe" `
        /Action:extract `
        /SourceServerName:$ServerName `
        /SourceDatabaseName:$DatabaseName `
        /TargetFile:$script_path\DACPACs\$DatabaseName.dacpac `
        /p:ExtractReferencedServerScopedElements=False `
        /p:IgnorePermissions=False
 
}