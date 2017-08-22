[string]$location = ""

# use mydomain.com
[string]$domain = read-host
[bool]$httponly = $false;

#BEWARE
# please note this is a like, making a mistake in this exclude list will break the software
# dont put "*.dll" in this list as i have a separate rule for that.
# this is for completly ignoring certain file types
[string[]]$excludeList = @("*\obj\*","*\bin\*","*nuget\*","*\packages\*", "*\MediaCache\*", "*\data\viewstate\*","*\data\diagnostics\*","*\data\indexes\*","*\data\serialization\*","*\data\tools\*","*\node_modules\*", "*\bower_components\*")

#, "*\sitecore\shell\*","*\sitecore\admin\*","*\sitecore\copyrights\*","*\sitecore\modules\*"

[string[]]$warnonce = @(
'glass.mapper.sc.web.mvc.glassview<'
);



[string[]]$phrasestoflag = @(
'SecurityDisabler(' # never switch security

'<style>',
'<script>', # too many script tags
'@ViewBag.', # find non strongly typed

$domain,
'fast:', # using a sql query when they should be using contentsearch api
'Getdatabase("', # reference fields

'~/media' # hard coded media in solution
'"{', # find the guids
'Sitecore.Data.ID("',# find the guids
'Html.Sitecore().Dictionary("', #find use of dictionary

'Translate.TextByDomain("', # find translation
'.Fields["', #find non constant fields
'case "', # find non constant fields
'userswitcher("', # switching users

'Sitecore.Diagnostics.Log.', # find any logging
'throw;', # loosing the stack trace
'Html.Sitecore().Rendering(', # static rendering
'UserControl', # user controls in a mvc world!
'Page.Session["', # storing session variables
'@Html.Sitecore().ControllerRendering(', #static controller rendering
'/*', # blanket comment
'// TODO' ## single comment
'/Sitecore/', #using a path when should be using a guid
'Sitecore.Context.Site.StartPath' # might be ok but depends on use.


# glassmapper based stuff

)

$hardcoded = New-Object System.Collections.ArrayList

$processed = New-Object System.Collections.ArrayList
$testprojects = New-Object System.Collections.ArrayList


#when we have discovered where sitecore exists we can do particular checks
[bool]$finduploadwatcher = $false;
[bool]$foundfeedhandler = $false;
[string]$sitecoreweb = "";
#[bool]$diagnostic = $true;
#[bool]$deepdiagnostic = $true;
[bool]$diagnostic = $false;
[bool]$deepdiagnostic = $false;
[int]$foundsearialisation = 0;
[string]$serialisationtype= "";
[int]$servicereference = 0;
[int]$mediacachesize = 0;
[int]$foundxslt = 0;
[int]$csprojfound=0;
[int]$csprojtestfound=0;
[bool]$showcrawing = $false;
[bool]$showfxm = $false;
[bool]$showlog = $false;
[bool]$shownpublising = $false;
[bool]$showsearch = $false;
[bool]$showwebdav = $false;
[string]$warning = "warning";
[string]$error = "error";
[string]$info = "informational";

[string]$category_hardcoded= "hardcoded";
[string]$category_filesettings= "filesetting";
[string]$category_tests= "test";
[string]$category_bestpractice= "bestpractice";

#accepted
#The Get-ChildItem cmdlet has an -Exclude parameter that is tempting to use but it doesn't work for filtering out entire directories from what I can tell. Try something like this:

function WriteLog([string]$messagetype,[string]$category, [string]$message)
{
    switch($messagetype)
    {
        $warning { Write-Host -f Yellow "$messagetype,$category, $message"}
        $error { Write-Host -f Red "$messagetype, $category, $message" }
        $info { Write-Host  "$messagetype,$category, $message" }
		$category_filesettings { Write-Host  "$messagetype,$category, $message" }
		$category_bestpractice { Write-Host  "$messagetype,$category, $message" }
		$category_hardcoded { Write-Host  "$messagetype,$category, $message" }

        default {
        Write-Host -f Magenta  'we do not support message type ' $messagetype;
        }
    }
}

function checkaccesslocation()
{

[string]$url = "";
# build up url for http only
if ($httponly -eq $true)
{
$url = "https://";
}
else
{
$url = "http://";
}

$url += $domain;
# need to do a curl here for files that defoe xist
#	.config
#	.xml
#	.xslt
#	.mrt


}

function shouldignore($file)
{
    # we dont want to print out anything for a folder
    if (Test-Path $file.FullName -PathType Container)
    {
  #   Write-Host -ForegroundColor Black -BackgroundColor Yellow 'testing ' + $file.FullName
 #   Write-Host -ForegroundColor DarkRed 'container example = ' + $file.FullName
    [string]$tostring = $file.FullName ;
        if ($tostring.ToLower().EndsWith("\sitecore") )
        {
            if (Test-Path ($tostring + "\shell")  -PathType Container)
            {
                if ([string]::IsNullOrEmpty($Global:sitecoreweb))
                {
                    $Global:sitecoreweb = $tostring.Replace("\sitecore","");
                }
            }
        }

        return $true;
    }

       if ($excludeList | Where {$file.FullName -like $_})
       {
            if ($file.FullName -like '*\mediacache\*')
               {
                $Global:mediacachesize++;
               }

           if ($deepdiagnostic)
           {
                Write-Host -ForegroundColor Green "am ignoring this because it matches " + $_ + ' source: '  + $file.FullName;
           }

       return $true;
      }

      if ($file.FullName -like '*.item')
      {
            $Global:foundsearialisation++;

             if ($diagnostic)
           {
           Write-Host -ForegroundColor Yellow "is serialization"  + $file.FullName;
           }
           return $true;
      }

      if ($file.FullName -like '*\service references\*')
      {
   #   $Global:servicereference++;

             if ($diagnostic)
           {
               Write-Host -ForegroundColor Blue   "service reference " + $file.FullName;
                   if ($file.FullName -like '*.disco')
                   {
                     Write-Host -ForegroundColor Red   "consider hiding the discovery file" + $file.FullName;
                   }
               }

           return $true;
      }

        if ($file.FullName -like '*.xslt')
      {
            if ($file.FullName -like '*sitecore\debug\Profile.xslt')
            {
                return $true;
            }

                if ($file.FullName -like '*sitecore\debug\Trace.xslt')
            {
                return $true;
            }
            if ($file.FullName -like '*shell\Applications\Debugger\counter.xslt')
            {
                return $true;
            }

            if ($file.FullName -like '*\shell\Templates\xsl.xslt')
            {
                return $true;
            }
            if ($file.FullName -like '*WebEdit\Hidden Rendering.xslt')
            {
                return $true;
            }

            if ($file.FullName -like '*xsl\sample rendering.xslt')
            {
				WriteLog -messagetype $error -category $category_bestpractice -message $("Found Sample XSLT rendering we recommend you remove this " + $file.FullName);


                return $true;
            }

            $Global:foundxslt++;
             if ($diagnostic)
           {
           Write-Host -ForegroundColor Green   "XSLT found " + $file.FullName;
           }
           return $true;
      }

    return $false;
}
function processhardcoded($filecontents)
{
    foreach ($phrase in $phrasestoflag)
    {
    $phraseoriginal = $phrase;
    $phrase = $phrase.ToLower();
        if($filecontents.Contains($phrase) -eq $true)
        {
        $result = $error +  'Error,Found hard coded value '+ $phraseoriginal + ','+ $file;
      #  $result;
        $hardcoded.Add($result)  > $null # dont want to show output
         }
    }
}
# need to process this against appconfig folders
function processconfig($file)
{

  [string]$filecontents = Get-Content $file;
    $filecontents = $filecontents.ToLower();
	# <add type="Sitecore.Resources.Media.UploadWatcher,Sitecore.Kernel" name="SitecoreUploadWatcher"/> 
	# disabling this https://doc.sitecore.net/sitecore_experience_platform/setting_up_and_maintaining/security_hardening/configuring/secure_the_file_upload_functionality
	if ($filecontents.Contains("sitecore.resources.media.uploadwatcher") -eq $true)
	{
	$finduploadwatcher = $true;
	}
	if ($filecontents.Contains("sitecore.shell.feeds.feedrequesthandler") -eq $true)
	{
	$foundfeedhandler = $true;
	}

	
}

function processcsfile($file)
{
  [string]$filecontents = Get-Content $file;
    $filecontents = $filecontents.ToLower();
    processhardcoded($filecontents);
}

function processcshtmlfile([string]$file)
{
    [string]$filecontents = Get-Content $file;
    $filecontents = $filecontents.ToLower();



    processhardcoded($filecontents);
 
	if (!$filecontents.Contains(".pagemode.issxperienceeditorediting") -eq $true)
	{
	#	WriteLog($warning,$category_bestpractice,"Cannot find PageMode.IsExperienceEditing on a CSHTML " + $file)
	}
	# TODO make sure we only warn once and keep a track of what we have warned against
	$hasfoundone = $false;
	foreach ($item in $warnonce)
	{
		if ($hasfoundone -eq $true)
		{
			continue;
		}

		if (!$filecontents.Contains($item) -eq $true)
		{
		$hasfoundone = $true;
	
						$message= 'we have found ' +$file;

				WriteLog -messagetype $warning -category $category_bestpractice -message $message;

		continue;
		}
	}
}
function processxmlfile($file)
{
}

function processcsprojfile($file)
{
    [string]$filecontents = Get-Content $file.FullName;
    $filecontents = $filecontents.ToLower();

    [string]$name = $file.Name;
    $name = $name.ToLower();
 #   if ($name -eq "web.config")
 #   {
 <#
        if ($filecontents.Contains("<MvcBuildViews>true</MvcBuildViews>".ToLower() -eq $false))
        {
            Write-Host 'recommend the web.config for debug MVC mvcbuildviews set to true in the CSproj'
        }#>
 #   }


 #	$file.ToLower().Contains(")
#look within the file to find test reference dlls..

     if ($file.FullName -like '*test*')
     {
        $Global:csprojtestfound++;
     }
     else
     {
        $Global:csprojfound++;
     }
}

function processlogs($file){
if ($file.FullName -like '*\logs\crawling.log*')
{
    $Global:showcrawing = $true;
    Write-Host 'Crawling Errors'
 }

 if ($file.FullName -like '*\logs\fxm.log*')
{
    $Global:showfxm = $true;
    Write-Host 'FXM Errors'
 }

 if ($file.FullName -like '*\logs\log.log*')
{
    $Global:showlog = $true;
    Write-Host 'Log Errors'
 }
 if ($file.FullName -like '*\logs\publishing.log*')
{
    $Global:shownpublising = $true;
    Write-Host 'publishing Errors'
 }

  if ($file.FullName -like '*\logs\search.log*')
{
    $Global:showsearch = $true;
    Write-Host 'Search Errors'
 }

  if ($file.FullName -like '*\logs\showwebdav.log*')
{
    $Global:showwebdav = $true;
    Write-Host 'WebDav Errors'
 }

  [string]$filecontents = Get-Content $file.FullName;
}

## look at the contents for each file
function processfile($file)
{
#Write-Host $file.FullName
#return;
<#
	if ($processed.Contains($file.FullName.ToLower()) -eq $true)
	{
		return;
	}
	else
	{
		[void]$processed.Add($file.FullName.ToLower());
	}
	#>
if (shouldignore($file))
{
    return;
}

    $extension =[System.IO.Path]::GetExtension($file.FullName).ToLower();

    switch($extension)
    {
	'.dll'{
		$message = "Wrong place unless its a library and then we recommend nuget " +  $file.FullName;

						WriteLog -messagetype $error -category $category_filesettings -message $message;


			return;
	}
        '.config' { processconfig($file.FullName);}
        '.xml' {processxmlfile($file.FullName); }
        '.cs' {processcsfile($file.FullName);}
        '.cshtml' {processcshtmlfile($file.FullName);}
		'.ascx' {
			$message = "found ascx file but would recommend using mvc " + $file.FullName;
	

				WriteLog -messagetype $warning -category $category_bestpractice -message $message;
		}
        '.csproj' {processcsprojfile($file);}
        '.txt' {processlogs($file);}
        '.gif' {}
        '.cur' {}
		'.js' {}
		'.item'{ $foundsearialisation++;
		
			if ($serialisationtype -eq "")
			{
				$serialisationtype= "TDS or Sitecore/ .Item";
			}
		}
		'.yml' { 
		
		$foundsearialisation++;
		
		if ($serialisationtype -eq "")
			{
				$serialisationtype= "Unicorn/ Yml";
			}
		}
		'.css' {}
		'.png' {}
		'.jpg' {}
		'.svg' {}
		'.xslt' { $foundxslt++;}
		'.json' {}
		'.htm' {


						WriteLog -messagetype $info -category $category_filesettings -message $('found html file' +  $file.FullName);


		}
		'.bat' {
			

						WriteLog -messagetype $info -category $category_filesettings -message $('found bat file'+  $file.FullName);

		}
		'.ps1' {
			
			WriteLog -messagetype $info -category $category_filesettings -message $('found ps1 file' +  $file.FullName);

		}
		'.psm1' {

			WriteLog -messagetype $info -category $category_filesettings -message $('found powershell module file' +  $file.FullName);
		}

		'.html' {
			$message = 'found html file'+  $file.FullName;

			WriteLog -messagetype $info -category $category_filesettings -message $message;
		}
		'.ts' {}
		'.md' {}
		'.pubxml' {
		

						$message= 'found publishing file ' +$file.FullName;

				WriteLog -messagetype $info -category $category_filesettings -message $message;
		}
		'.example' {
				$message= 'found example file ' +$file.FullName;

				WriteLog -messagetype $warning -category $category_filesettings -message $message;
		}
		'.exclude' {
				WriteLog -messagetype $warning -category $category_filesettings -message $('excluded file in project ' +$file.FullName);
		}
        default {
     #   Write-Host 'ignored '+ $file.FullName;
        }
    }
    #$file.FullName
}

function separator
{
    Write-Host '--------------------------------------------------------------------------------';
}
## recursivily look through all files
# using this kindof http://stackoverflow.com/questions/8024103/how-to-retrieve-a-recursive-directory-and-file-list-from-powershell-excluding-so
function GetFiles($path = $pwd)
{
#$path
    foreach ($file in Get-ChildItem $path)
    {
        processfile($file)
        if (Test-Path $file.FullName -PathType Container)
        {
            GetFiles $file.FullName
        }
    }
}

function DeleteIrrelevantContents($location)
{
# i need to find the website that has data\viewstates in
# https://blogs.technet.microsoft.com/heyscriptingguy/2012/02/22/the-best-way-to-use-powershell-to-delete-folders/
}

function DetectModules($location){
Write-Host "Modules Installed at " $location
    foreach($item in Get-ChildItem $location)
    {
        $item.Name
    }
}

<#
Clear-Host

    [string]$tostring = "asdfasdf\sitecore";
    Write-Host ''
        if ($tostring.EndsWith("\sitecore"))
        {
   $shouldbetrue = $tostring.ToLower().Contains("\sitecore\shell");
            if ($shouldbetrue -eq  $false)
            {
            $tostring
            }
        }
        else
        {
        "no match"
        }

        #>

        function addlog($warninglevel,$error,$expected,$file){
        }
function CheckCSProjToTest
{
    if ($csprojtestfound -eq 0)
    {


				WriteLog -messagetype $warning -category $category_bestpractice -message 'No Test projects found';
    }

      if ($csprojtestfound -gt 0 -and $csprojtestfound -lt $csprojfound )
    {


					WriteLog -messagetype $info -category $category_bestpractice -message $( $csprojtestfound.ToString() +' Test projects found');
    }

}

function showxsltmessage
{
    [int]$xsltthreshold = 0;
    if ($foundxslt -gt $xsltthreshold)
    {
    $warningmessage = 'Found '+$foundxslt + ' xslt as its over $xsltthreshold we recommend that you primary use c# instead for maintenance reasons'

			WriteLog -messagetype $warning -category $category_bestpractice -message $infomessage;
    }
    else
    {
    $infomessage = 'Found ' + $foundxslt + ' xslt items we recommand that c# is mostly used'


		WriteLog -messagetype $info -category $category_bestpractice -message $infomessage;
    }
}

function checkserialization
{
    [int]$serializationthreshold = 1000;
    if ($foundsearialisation -gt $serializationthreshold)
    {
        $errormessage ='your solution has over ' + $serializationthreshold + ' items serialized  and we recommend keeping this under $serializationthreshold consider separating development from content otherwise your deployments may take longer via devops'

	

				WriteLog -messagetype $info -category $category_bestpractice -message $errormessage;
    }
    else
    {
        $errormessage = 'your serialization  has '+$foundsearialisation +' which is <  '+$serializationthreshold+' items; please keep mindful of the size as deployment via devops will slow down'

			WriteLog -messagetype $info -category $category_bestpractice -message $errormessage;

    }
}

##Write-Host 'uses service references '   $servicereference
#Write-Host 'media cache size'  $mediacachesize

Clear-host
Write-Host  -ForegroundColor Red 'Results'
Write-Host 'diagnostic is '  $diagnostic
Write-Host 'deep diagnositc is ' $deepdiagnostic
Write-Host  'Starting to process files against rules'
##Write-Host -ForegroundColor Red 'Error'
#Write-Host -ForegroundColor Green 'warning'
#Write-Host -ForegroundColor Blue   "service reference"
#Write-Host -ForegroundColor Yellow "is serialization"
#Write-Host -ForegroundColor DarkCyan  "file in Wrong place "

Set-Location $location

DeleteIrrelevantContents($location);
separator;
GetFiles $location
separator;
checkserialization;
separator;
showxsltmessage;
separator;
WriteLog -messagetype $info -category $category_bestpractice -message $("serialisation type"+ $serialisationtype);
separator;
Write-Host 'Hard coded values found'
$hardcoded
separator;
Write-Host 'upload watcher exists (hoping for false)'  	$finduploadwatcher
Write-Host 'feed handler exists (hoping for false)'  	$foundfeedhandler
CheckCSProjToTest;

# set where modules are
$sitecoreweb = ($sitecoreweb + '\sitecore modules\Web')
DetectModules $sitecoreweb
separator;

#Write-Host 'Ideas to work on'
#look within feature for glassmapper that should not be there (prs for music)
#Write-Host '----------------- need to do this on dev and UAT'
#Write-Host '----------------- create delete viewstate and mediacache by filling out DeleteIrrelevantContents'
#Write-Host '----------------- check for trusted in webconfig'
#Write-Host '----------------- need to scan logfiles for warning and errors'
#Write-Host '----------------- write out what packages are installed from package dir'
#Write-Host '----------------- need to run sql scripts against db'
#Write-Host '----------------- find dll version mismatches'
#Write-Host '----------------- list of packages installed'
#Write-Host '----------------- check against seiralization structure the renderings, layouts,templates,placeholders are in their own section if serialization count > 400 then you are putting in all your content?'
#Write-Host '----------------- check for module modules \sitecore modules\Web'
#Write-Host '----------------- check for speakui in sitecore\shell'
#Write-Host '----------------- check for speakui in should also tell me next steps'
#Write-Host '----------------- separation of sitecore and website should be in different projects'

<#
find items code not set to compile..
search for the domain name principality.co.uk
sitecore cop in rocks
IComputedIndexField
@{  } (if > 10 lines then mark
cclasses that inherit Base : IBase
SuppressMessage
Translate.TextByDomain("
.Fields["
 case " -> consider enums
stuff to search for /*
Getdatabase("
userswitcher
SecurityDisabler
glassmapper
webedit="false"
Sitecore.Diagnostics.Log.
throw;
       MvcHandler.DisableMvcResponseHeader = true;
UsedImplicitly attribute

          // ReSharper disable PossibleLossOfFraction
                return initialDeposit * (1 + monthlyBonusRate * duration) + (monthlyDeposit * monthlyBonusRate * ((duration * (duration + 1)) / 2) + totalDeposited);
                // ReSharper restore PossibleLossOfFraction

HttpRequestProcessor
UsedImplicitly attribute
MiniProfiler.Start
http://miniprofiler.com/
 RegisterBundles(BundleTable.Bundles);

            GlobalConfiguration.Configure(this.ConfigureRoutes);

MiniProfiler.Current
       MvcHandler.DisableMvcResponseHeader = true;

// find all the disabled and example files..

  [SuppressMessage("Microsoft.Naming", "CA1704", Justification = "Naming loop")]

identify classnames and interfaces and check where they are used..

/////////////
in layout.. by looking at      @Html.Sitecore().Placeholder("Main")

    if ((string)Sitecore.Context.Items["is404"] == "true")
    {
        HttpContext.Current.Response.StatusCode = (int)HttpStatusCode.NotFound;
        HttpContext.Current.Response.TrySkipIisCustomErrors = true;
    }

 <meta charset="utf-8" />
    <title>@(!string.IsNullOrWhiteSpace(Model.PageDescription) ? @Model.PageDescription + " | " + @Model.Title : @Model.Title)</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <meta name="Description" content="@Model.MetaDescription" />
    <meta name="Keywords" content="@Model.MetaKeywords" />
    <meta name="robots" content="@Model.MetaRobots">

    <link rel="canonical" href="@CanonicalHelper.CanonicalHref" />
    <link rel="alternate" href="@CanonicalHelper.AlternateHref" hreflang="@CanonicalHelper.AlternateLinkLanguage" />

    detection of the right google analytics -> google-analytics.com/ga.js

    ///////// NUnit xUnit / MsText

    check if an appsettings has a guid on it! and flag it maybe?

    search for SmtpClient client.. this should be its own service

    SuppressMessage in .cs file

    the parent folder and the client name

    find all handlers and check for empty ones..

    public static class ArmatureHelper

    Sitecore.Diagnostics.Assert

          /// Does a full update on all items based on the mortgage products template (potentially a long operation, to be done on a scheduled task)
        /// Uses a DatabaseSwitcher because we may not be in the usual Sitecore context (i.e. during a scheduled task)
        /// </summary>
        public static void RefreshAllMortgageProducts()

        // look at a scheduled task

        csproj.. any .cs set to content

finding values
============
section.. config,code,role
search..|title|string to find -- spit out title url
static renders
use of try
use of logging?..
comments
use of sitecore api vs searchcontent
pipelines and modules (see if they are in sitecore)
exception handling
================
use of try and bubble up
definition usage
=============
cshtml and controller content not used

interface usage
==============
find interfaces.. find where they are used
show where interface not used
stategy pattern
=============
find abstacts.. where they are used and inherited
show where no inheritance
use of static
===========
bad for unit tests (ignore sitecore)

cshtml
=======
use of .item for experience editor
maintenance
============
class functions less than 30 lines long

config confirm all
===============
encryption on connection strings
xslt cache has xslt
xslt is using warning

#>

<#

Code review checklist
use of interfaces and where their class lie to identify a pattern
need to identify patterns somehow in naming

#>