#https://docs.microsoft.com/en-us/azure/app-service-web/web-sites-staged-publishing

$sitecoreazuretoolkit ="C:\Sitecore Azure Toolkit 1.1 rev 170509\";
$msDeployPath = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

# always clean up - run the cleanup function
# 1 change $prefix only
# 2 decide whether you want to use autoswap or staged swap
#   if staged then you need to verify your website by visiting it and then finished the staged swap

Clear-Host;

######################## Variables #########################################
$cleanup = $true;
$prefix = "pga-demoworkshop";
$resourcegroupname = "$prefix-resourcegroup";
$appname ="$prefix-appname"
$slotname ="$prefix-production";
$location = "West Europe";
$appserviceplan = "$prefix-appserviceplan"


######################## Support functions #########################################

function login
{

	Login-AzureRmAccount 
	$AzureSubscriptionId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4";#"SE-EMEA_Nordics-SA-POC-INT-AMP-950";
	Set-AzureRmContext -SubscriptionID $AzureSubscriptionId

}

function notify($message, $shouldnotify)
{

	Write-Host -ForegroundColor Red  $message
	if ($shouldnotify -eq "1")
	{

	}


}

function cleanup()
{
	Remove-AzureRmResourceGroup -ResourceGroupName   $resourcegroupname -Force -Verbose;
}

######################## Start of script #########################################

# login if we need to
login;

# Delete reosurce group
if ($cleanup -eq $true)
{
	cleanup;
}


# Create resource group
New-AzureRmResourceGroup  -Name $resourcegroupname -Location $location 

# Create service plan
New-AzureRmAppServicePlan -Location $location -Name $appserviceplan -ResourceGroupName $resourcegroupname


notify("upgrading to standard tier for slots on the app service plan","0")
# Upgrade App Service plan to Standard tier (minimum required by deployment slots)
Set-AzureRmAppServicePlan -Name $appserviceplan  -ResourceGroupName $resourcegroupname -Tier Standard


notify("Create a web app","0")
$myapp = New-AzureRmWebApp -ResourceGroupName $resourcegroupname -Name $appname -Location $location `
-AppServicePlan $appserviceplan 


# Set app settings variables
notify("Set Production name","0")
Set-AzureRmWebApp -ResourceGroupName $resourcegroupname -Name $appname `
-AppSettings @{"SlotName" = "Production"; "Environment" = "Production"}  


# credentials for main production slot for publishing
$creds = Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/config -ResourceName "$appname/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$creds.properties.publishingUserName
$path = $myapp.DefaultHostName;

notify("deploy app in $path",0)
##########################
<# Sample


"C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy" 
-verb=sync 
-source:package="C:\projects\review\PR\output\v1-ProductionSlot\deploymentslotdemo.zip" 
-dest:auto,Computername=https://pga-demoworkshop-appname.scm.azurewebsites.net/:443/msdeploy.axd?site="pga-demoworkshop-appname",Username="$pga-demoworkshop-appname",Password="l8vsuyHewqpCzvD0LRnTxHfEse8o4rwfwlQXCS9HhSuNpxieW111KqcbyYvS",AuthType="Basic" -enableRule:DoNotDeleteRule -allowUntrusted
#>

########################## Begin Azure deployment example ####################################
Set-location -Path $sitecoreazuretoolkit
Import-Module ".\tools\Sitecore.Cloud.Cmdlets.psm1"
$SKU="xp1"

# doesnt exist.. its always a version or two behind..
$Version="8.2.5"

$Resources="$sitecoreazuretoolkit\resources\$Version"

$Website="C:\inetpub\wwwroot\habitat.dev.local\Website"

$Output="C:\Azure-Packages"

Start-SitecoreAzurePackaging -sitecorePath "$Website" -destinationFolderPath $Output `
-cargoPayloadFolderPath "$Resources\cargopayloads" -commonConfigPath "$Resources\configs\common.packaging.config.json" `
-skuConfigPath "$Resources\configs\$SKU.packaging.config.json" -archiveAndParameterXmlPath  "$Resources\msdeployxmls" -fileVersion 1.0





$msdeploy = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
$username = $creds.properties.publishingUserName;
$password = $creds.properties.publishingPassword;
$msdeployArgs = @(
"-verb:sync",
"-source:package='C:\projects\review\PR\output\v1-ProductionSlot\DeploymentSlotDemo.zip'",
"-verbose",
"-dest:auto,Computername=https://$appname.scm.azurewebsites.net:443/msdeploy.axd?site='$appname',Username='$username',Password='$password',AuthType='Basic' -enableRule:DoNotDeleteRule -allowUntrusted"
)

Start-Process $msdeploy -NoNewWindow -ArgumentList $msdeployArgs -Wait
########################## End Azure deployment example ####################################

notify("todo","0")

# we want to see what we created
notify("What did we just deploy on the main slot",0)
$path ="http://" + $myapp.DefaultHostName;
Start-Process "chrome.exe" "$path" -Wait


notify("Create a deployment slot","0")  
$slot = New-AzureRmWebAppSlot -ResourceGroupName $resourcegroupname -Name $appname -Slot $slotname `
 -AppServicePlan $appserviceplan 

notify("Add AppSettings / etc","0")  
Set-AzureRmWebApp -ResourceGroupName $resourcegroupname -Name $appname `
-AppSettings @{"SlotName" = "Pre-Production"; "Environment" = "Production"}  

# credentials for secondary slot
$creds = Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname -ResourceType Microsoft.Web/sites/config -ResourceName "$slot/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$creds.properties.publishingUserName


notify("deploy app in slot $slotname to endpoint $slot.DefaultHostName","0")  

########################## Begin Azure deployment example ####################################
$msdeploy = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe"
$username = $creds.properties.publishingUserName;
$password = $creds.properties.publishingPassword;
# the slot name is appname/Slotname so we have replace the / with -
$slothost = $slot.Name.ToString().Replace("/","-");
$msdeployArgs = @(
"-verb:sync",
"-source:package='C:\projects\review\PR\output\v2-Pre-ProductionSlot\DeploymentSlotDemo.zip'",
"-verbose",
"-dest:auto,Computername=https://$slothost.scm.azurewebsites.net:443/msdeploy.axd?site='$appname',Username='$username',Password='$password',AuthType='Basic' -enableRule:DoNotDeleteRule -allowUntrusted"
)

Start-Process $msdeploy -NoNewWindow -ArgumentList $msdeployArgs -Wait
########################## End Azure deployment example ####################################
notify("todo","0")
$path = "http://" + $slot.DefaultHostName;
notify("What did we just deploy on the preproduction slot",0)
Start-Process "chrome.exe" "$path" -Wait


notify('1 initiate a swap with review (multi-phase swap) and apply destination slot configuration to source slot',"0")  
notify('0 auto swap',0)
$choice  = Read-Host;

if ($choice -eq "1")
{
	notify("chosen initiate a swap with review (multi-phase swap) and apply destination slot configuration to source slot",0);	
	$ParametersObject = @{targetSlot  = "production"};
	Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname `
	-ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname `
	-Action applySlotConfig -Parameters $ParametersObject -ApiVersion 2015-07-01 -Force 

	# we want to see what we created
	$path = "http://" + "$slot.DefaultHostName";
	Start-Process "chrome.exe" "$path" -Wait

	notify("was testing successful?",0);
	notify("1 for yes or 0 for no",0);
	$testsuccess = Read-Host;
	if ($testsuccess -eq "0")
	{
		notify("Cancel a pending swap (swap with review) and restore source slot configuration",0);
		Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname `
		-ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname `
		-Action resetSlotConfig -ApiVersion 2015-07-01 -Force -Debug
		notify("Showing main website as swap was NOT successful",0);

	}
	else
	{
		notify("Swapping slots",0);
		$ParametersObject = @{targetSlot  = "production"}
		Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname `
		-ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname `
		-Action slotsswap -Parameters $ParametersObject -ApiVersion 2015-07-01 -Force 

		notify("Showing main website as swap was successful",0);
	}

}
else
{

	notify("you chose Swap deployment slots",0);
	$ParametersObject = @{targetSlot  = "production"}
	Invoke-AzureRmResourceAction -ResourceGroupName $resourcegroupname `
	-ResourceType Microsoft.Web/sites/slots -ResourceName $appname/$slotname `
	-Action slotsswap -Parameters $ParametersObject -ApiVersion 2015-07-01 -Force 

	notify("Showing main website as swap was successful",0);
}

#https://stackoverflow.com/questions/11885454/msdeploy-deploying-contents-of-a-folder-to-a-remote-iis-server