#
# naming.ps1
#
cls;

function login
{

Login-AzureRmAccount 
$AzureSubscriptionId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4";#"SE-EMEA_Nordics-SA-POC-INT-AMP-950";
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId

}

$runlogin = $true

if ($runlogin -eq $false)
{

# find out whether we are logged into azure and then login if we are not logged in
Try {
  Get-AzureRmContext
} Catch {
  if ($_ -like "*Login-AzureRmAccount to login*") {
	login;
  }
}
}
else
{
	login;
}

$list = Get-AzureRmResource 

foreach($item in $list)
{
[bool]$shouldwarn = $false;
[string]$errormessage= "";
	[string]$name = $item.Name;
	if ($name.IndexOf("-") -ne 3)
	{
		$shouldwarn = $true;	
		$errormessage = "Incorrect naming";
	}
	else
	{
		#Write-Host "Good - "  $item.Name
	}
	if ($item.ResourceType.ToString() -Like '*storageAccounts*')
	{
		if ($item.Sku.name.Contains("Standard_LRS") -eq $false)
		{
		$shouldwarn = $true;
		$errormessage += " - wrong storage"
		}
	
	}



	if($shouldwarn)
	{
			Write-Host -ForegroundColor Red  $($item.Name + " " + $item.ResourceType  + " " + $item.Sku + " " + $item.tier + " " + $errormessage)
	}


}
# allowed shared instances.. ai - storage