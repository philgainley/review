#https://docs.microsoft.com/en-us/azure/app-service-web/web-sites-staged-publishing

$prefix = "pga-demoworkshop";
$resourcegroupname = "$prefix-resourcegroup";
$appname ="$prefix-Testname"
$slotname ="$prefix-production";
$location = "West Europe";
$appserviceplan = "$prefix-appserviceplan"

function login
{

Login-AzureRmAccount 
$AzureSubscriptionId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4";#"SE-EMEA_Nordics-SA-POC-INT-AMP-950";
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId

}

login;


Write-Host -ForegroundColor Red  "Create a web app"
New-AzureRmWebApp -ResourceGroupName $resourcegroupname -Name $appname -Location $location -AppServicePlan $appserviceplan

Write-Host -ForegroundColor Red "deploy app"
Write-Host -ForegroundColor green "todo"

Write-Host -ForegroundColor Red  "Create a deployment slot"
New-AzureRmWebAppSlot -ResourceGroupName $resourcegroupname -Name $appname -Slot $slotname -AppServicePlan $appserviceplan

Write-Host -ForegroundColor Red "deploy app in slot"
Write-Host -ForegroundColor green "todo"

Write-Host '1 initiate a swap with review (multi-phase swap) and apply destination slot configuration to source slot'
Write-Host '2 auto swap'
$choice  = Read-Host;

if ($choice -eq "1")
{
	Write-Host -ForegroundColor Red "chosen initiate a swap with review (multi-phase swap) and apply destination slot configuration to source slot"

	$ParametersObject = @{targetSlot  = $slotname}
	Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname -Action applySlotConfig -Parameters $ParametersObject -ApiVersion 2015-07-01

	Write-Host -ForegroundColor Red "was testing successful?"
	Write-Host -ForegroundColor Red "1 for yes or 2 for no"
	$testsuccess = Read-Host;
	if ($testsuccess -eq "0")
	{
		Write-Host -ForegroundColor Red  "Cancel a pending swap (swap with review) and restore source slot configuration"
		Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname -Action resetSlotConfig -ApiVersion 2015-07-01
		Write-Host -ForegroundColor Red "Showing main website as swap was NOT successful"

	}
	else
	{
		Write-Host -ForegroundColor Red  "Swapping slots"	
		$ParametersObject = @{targetSlot  = $slotname}
		Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname -Action slotsswap -Parameters $ParametersObject -ApiVersion 2015-07-01

		Write-Host -ForegroundColor Red "Showing main website as swap was successful"
	}

}
else
{

	Write-Host -ForegroundColor Red "you chose Swap deployment slots"
	$ParametersObject = @{targetSlot  = $slotname}
	Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname -Action slotsswap -Parameters $ParametersObject -ApiVersion 2015-07-01

	Write-Host -ForegroundColor Red "Showing main website as swap was successful"
}
