$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Stop'

$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}

. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
. (Join-Path $PSScriptRootV2 'createportal.ps1')
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\NAVOffice365Administration\NAVOffice365Administration.psm1"
Import-module (Join-Path $PSScriptRootV2 'NavInO365.dll')

$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$thumbprint = $config.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").value
$publicSoapBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").value
$publicWebBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").value
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value

$WebConfigFile = "C:\inetpub\wwwroot\$ServerInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
$WebClientRegionFormat = $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='RegionFormat']").Value
$WebClientLanguage = $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='Language']").Value
$dnsidentity = $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='DnsIdentity']").Value

if (!$thumbprint) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}
if ($multitenant -ne "false") {
    while ($true) { throw "Server is multi-tenant, cannot apply this package." }
}

# AppWrite-Verbose "Create App and Portal"
$appClientId = [guid]::NewGuid().Guid
$appFeatureId = "8c49cbd0-7834-4231-b166-2f9408628a9d"
$appProductId = [guid]::NewGuid().Guid
$appSecret = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("Microsoft Dynamics NAV AppSecret"));  # Must be 32 characters

$languages = @{ 
    "da-DK" = "Danish - Denmark";
    "de-AT" = "German - Austria";
    "de-CH" = "German - Switzerland";
    "de-DE" = "German - Germany";
    "cs-CZ" = "Czech - Czech Republic";
    "en-AU" = "English - Australia"; 
    "en-CA" = "English - Canada";
    "en-GB" = "English - United Kingdom";
    "en-IN" = "English - India";
    "en-NZ" = "English - New Zealand";
    "en-US" = "English - United States";
    "es-ES" = "Spanish - Spain";
    "es-MX" = "Spanish - Mexico";
    "fi-FI" = "Finnish - Finland";
    "fr-BE" = "French - Belgium";
    "fr-CA" = "French - Canada";
    "fr-CH" = "French - Switzerland";
    "fr-FR" = "French - France";
    "is-IS" = "Icelandic - Iceland";
    "it-CH" = "Italian - Switzerland";
    "it-IT" = "Italian - Italy";
    "nb-NO" = "Norwegian (Bokmål) - Norway";
    "nl-BE" = "Dutch - Belgium";
    "nl-NL" = "Dutch - Netherlands";
    "ru-RU" = "Russian - Russia";
    "sv-SE" = "Swedish - Sweden";
}


$NAVAdminUser = Get-UserInput -Id NavAdminUser -Text "NAV administrator username" -Default "admin"
$SharePointAdminLoginname = Get-UserInput -Id SharePointAdminLoginname -Text "Office 365 administrator E-mail (example: somebody@cronus.onmicrosoft.com)"
$SharePointAdminPassword = Get-Variable -name "HardcodeSharePointAdminPassword" -ValueOnly -ErrorAction SilentlyContinue
if ($SharePointAdminPassword) {
    $SharePointAdminSecurePassword = ConvertTo-SecureString -String $SharePointAdminPassword -AsPlainText -Force
} else {
    $SharePointAdminSecurePassword = Read-Host "Office 365 administrator Password" -AsSecureString
}
$SharePointAdminPassword = Decrypt-SecureString $SharePointAdminSecurePassword
$SharePointAdminCredential = New-Object System.Management.Automation.PSCredential ($SharePointAdminLoginname, $SharePointAdminSecurePassword)

do {
    $err = $false
    $SharePointUrl = ""
    if ($SharePointAdminLoginname.EndsWith('.onmicrosoft.com')) {
        $SharePointUrl = ('https://' + $SharePointAdminLoginname.Split('@')[1].Split('.')[0] + '.sharepoint.com')
    }
    $SharePointUrl = Get-UserInput -Id SharePointUrl -Text "SharePoint Base URL (example: https://cronus.sharepoint.com)" -Default $SharePointUrl
    while ($SharePointUrl.EndsWith('/')) {
        $SharePointUrl = $SharePointUrl.SubString(0, $SharePointUrl.Length-1)
    }
    if ((!$SharePointUrl.ToLower().EndsWith(".sharepoint.com")) -or (!$SharePointUrl.ToLower().StartsWith("https://"))) {
        $err = $true
        Write-Host -ForegroundColor Red "SharePoint URL must be formed like: https://tenant.sharepoint.com"
    }
} while ($err)

$SharePointAppCatalogName = Get-UserInput -Id SharePointAppCatalogName -Text "What is the name of your App Catalog site on SharePoint" -Default "AppCatalog"

do {
    Write-Host "Languages:"
    $languages.GetEnumerator() | % { Write-Host ($_.Name + " = " + $_.Value) }
    $SharePointLanguage = Get-UserInput -Id SharePointLanguage -Text "SharePoint Language" -Default $WebClientLanguage.Substring(0,5)
    $LanguageFile = (Join-Path $PSScriptRootV2 "O365Translations\$SharePointLanguage.ps1")
} while (!(Test-Path $LanguageFile))

$SharePointMultitenant = Get-UserInput -Id SharePointMultitenant -Text "Is the SharePoint portal going to be integrated to a multitenant NAV? (Yes/No)" -Default "No"
if ($SharePointMultitenant -eq "Yes") {
    $SharePointSite = "default"
    ('$SharePointInstallFolder = "' + $PSScriptRootV2 + '"')            | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointAdminLoginname = "' + $SharePointAdminLoginname + '"') | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointAdminPassword = "' + $SharePointAdminPassword + '"')   | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointUrl = "' + $SharePointUrl + '"')                       | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointLanguageFile = "' + $LanguageFile + '"')               | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointAppClientId = "' + $appClientId + '"')                 | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointAppFeatureId = "' + $appFeatureId + '"')               | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
    ('$SharePointAppProductId = "' + $appProductId + '"')               | Add-Content "C:\DEMO\Multitenancy\HardcodeInput.ps1"
} else {
    $SharePointSite = Get-UserInput -Id SharePointSite -Text "SharePoint Site Name" -Default ($env:COMPUTERNAME.ToLower())
}

. $LanguageFile

$SharePointTimezoneId = Get-UserInput -Id SharePointTimezoneId -Text "SharePoint Timezone ID (see http://blog.jussipalo.com/2013/10/list-of-sharepoint-timezoneid-values.html)" -Default $SharePointTimezoneId

# Set default profile to Small Business
$SmallBusiness = $Profiles['Small Business']
Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
"USE [Demo Database NAV (8-0)]
GO
UPDATE [dbo].[Profile]
   SET [Default Role Center] = 0
GO
UPDATE [dbo].[Profile]
   SET [Default Role Center] = 1
 WHERE [Profile ID] = '$SmallBusiness'
GO
IF EXISTS (SELECT * FROM [dbo].[Document Service] WHERE [Service ID]='SERVICE 1')
    UPDATE [dbo].[Document Service]
       SET [Description] = 'Office 365 Documents repository'
          ,[Location] = '$SharePointUrl/sites/$SharePointSite'
          ,[User Name] = '$SharePointAdminLoginname'
          ,[Password] = '$SharePointAdminPassword'
          ,[Document Repository] = '$DocumentsTitle'
          ,[Folder] = 'Temp'
     WHERE [Service ID] = 'SERVICE 1'
ELSE
    INSERT INTO [dbo].[Document Service]
               ([Service ID]
               ,[Description]
               ,[Location]
               ,[User Name]
               ,[Password]
               ,[Document Repository]
               ,[Folder])
         VALUES
               ('SERVICE 1'
               ,'Office 365'
               ,'$SharePointUrl/sites/$SharePointSite'
               ,'$SharePointAdminLoginname'
               ,'$SharePointAdminPassword'
               ,'$DocumentsTitle'
               ,'Temp')
GO"

cd $PSScriptRootV2

# Connect to Microsoft Online Service
Write-Verbose "Connect to MSOL"
Connect-MsolService -Credential $SharePointAdminCredential -ErrorAction Stop
$publicWebBaseUrl = $publicWebBaseUrl.Replace("/$ServerInstance/", "/AAD/")
$SharePointSiteUrl = "$SharePointUrl/sites/$SharePointSite"
# Create new Web Server Instance
if (!(Test-Path "C:\inetpub\wwwroot\AAD")) {
    Write-Verbose "Create NAV WebServerInstance"
    New-NAVWebServerInstance -ClientServicesCredentialType AccessControlService -ClientServicesPort 7046 -DnsIdentity $dnsidentity -Server localhost -ServerInstance $serverInstance -WebServerInstance AAD -RegionFormat $WebClientRegionFormat -Language $WebClientLanguage -AcsUri "https://www.bing.com" -Company $Company

    # Change Web.config
    $NAVWebConfigFile = "C:\inetpub\wwwroot\$ServerInstance\Web.config"
    $NAVWebConfig = [xml](Get-Content $NAVWebConfigFile)

    $AADWebConfigFile = "C:\inetpub\wwwroot\AAD\Web.config"
    $AADWebConfig = [xml](Get-Content $AADWebConfigFile)
    $AADWebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='TimeZone']").value = $NAVWebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='TimeZone']").value
    $AADWebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='HelpServer']").value = $NAVWebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='HelpServer']").value
    $AADWebConfig.Save($AADWebConfigFile)
}

# Enable single sign on
Write-Verbose "Enable Single Sign-On"
Set-NavSingleSignOnWithOffice365 -NavServerInstance $serverInstance -NavWebServerInstanceName AAD -NavUser $NavAdminUser -AuthenticationEmail $SharePointAdminLoginname -AuthenticationEmailPassword $SharePointAdminSecurePassword -NavServerCertificateThumbprint $thumbprint -NavWebAddress $publicWebBaseURL -Verbose

# Import NAV Objects
Write-Verbose "Import NAV Objects"
$NavIde = 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'
Import-NAVApplicationObject -Path (Join-Path $PSScriptRootV2 "Fobs\$Language.fob") -NavServerInstance $serverInstance -DatabaseServer 'localhost\NAVDEMO' -DatabaseName 'Demo Database NAV (8-0)' -ImportAction Overwrite -Confirm:$false
Copy-Item (Join-Path $PSScriptRootV2 "Translations") "C:\Program Files\Microsoft Dynamics NAV\80\Service" -Recurse -Force
Copy-Item (Join-Path $PSScriptRootV2 "Office.png") "C:\inetpub\wwwroot\AAD\WebClient\Resources\Images\Office.png" -Force
Copy-Item (Join-Path $PSScriptRootV2 "myapps.png") "C:\inetpub\wwwroot\AAD\WebClient\Resources\Images\myapps.png" -Force

# Add pages to WarmupNAV pages.txt
Write-Verbose "Add Warmup Pages"
Add-WarmupPages -Path (Join-Path $PSScriptRootV2 "WarmupPages.txt")

# Restart NAV Service Tier
Write-Verbose "Restart Service Tier"
Set-NAVServerInstance -ServerInstance $serverInstance -Restart

# Modify Desktop.ascx to include a link to SharePoint
Write-Verbose "Modify Desktop.ascx"
$desktopAscxFile = "C:\inetpub\wwwroot\AAD\WebClient\desktop.ascx"
$desktopAscx = (Get-Content $desktopAscxFile)
$idx = 0
while ($idx -lt ($desktopAscx.Length-6))
{
    if ($desktopAscx[$idx].Trim().Equals('<div class="ms-core-deltaSuiteLinks" id="DeltaSuiteLinks">') -and
      $desktopAscx[$idx+1].Trim().Equals('<div id="suiteLinksBox">') -and
      $desktopAscx[$idx+2].Trim().Equals('<asp:PlaceHolder ID="TopNavigationPlaceHolder" runat="server"></asp:PlaceHolder>') -and
      $desktopAscx[$idx+3].Trim().Equals('</div>') -and
      $desktopAscx[$idx+4].Trim().Equals('</div>')) 
    {
        $end1 = $idx-7
        $start1 = $idx-6
        if (!($desktopAscx[$end1].Trim().Equals('<div class="ms-tableRow">')))
        {
            $end1 -= 3
        }

        $start2 = $idx+5
        if ($desktopAscx[$start2].Trim().Equals('<div class="ms-tableCell ms-core-brandinglogo">'))
        {
            $start2 += 3
        }

        $stream = [System.IO.StreamWriter] $desktopAscxFile

        0..$end1 | % {
            $stream.WriteLine($desktopAscx[$_])
        }

        $stream.WriteLine('              <div class="ms-tableCell ms-core-brandinglogo">')
        $stream.WriteLine('                <a href="https://portal.office.com/myapps"><img Src="/AAD/WebClient/Resources/Images/myapps.png" Title="Go to My Apps"></a>')
        $stream.WriteLine('              </div>')

        $start1..($idx+4) | % {
            $stream.WriteLine($desktopAscx[$_])
        }
        $stream.WriteLine('              <div class="ms-tableCell ms-core-brandinglogo">')
        if ($SharePointMultitenant -eq "Yes") {
            $stream.WriteLine('                <a href="javascript:O365('''+$SharePointUrl+''')"><img Src="/AAD/WebClient/Resources/Images/Office.png" Title="Go to Office 365"></a>')
        } else {
            $stream.WriteLine('                <a href="javascript:O365('''+$SharePointSiteUrl+''')"><img Src="/AAD/WebClient/Resources/Images/Office.png" Title="Go to Office 365"></a>')
        }
        $stream.WriteLine('              </div>')
        $start2..($desktopAscx.Length-1) | % {
            $stream.WriteLine($desktopAscx[$_])
        }
        $stream.close()
        break
    }
    $idx++
}

# Modify Default.master to include a link to SharePoint
Write-Verbose "Modify Default.master"
$defaultMasterFile = "C:\inetpub\wwwroot\AAD\WebClient\default.master"
$defaultMaster = (Get-Content $defaultMasterFile)
$idx = 0
$exists = $false
while ($idx -lt ($defaultMaster.Length-2)) {
    if ($defaultMaster[$idx].Trim().Equals("</head>")) {
        if (!$exists) {
            $stream = [System.IO.StreamWriter] $defaultMasterFile
            0..($idx-1) | % {
                $stream.WriteLine($defaultMaster[$_])
            }

            $stream.WriteLine('<script language="javascript" type="text/javascript">')
            $stream.WriteLine('function getParameterByName(name) {')
            $stream.WriteLine('    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");')
            $stream.WriteLine('    var regex = new RegExp("[\\?&]" + name + "=([^&#]*)");')
            $stream.WriteLine('    results = regex.exec(location.search);')
            $stream.WriteLine('    return results == null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));')
            $stream.WriteLine('}')
            $stream.WriteLine('function O365(O365tenant)')
            $stream.WriteLine('{')
            $stream.WriteLine('    var O365site = getParameterByName("tenant");')
            $stream.WriteLine('    if (O365site == "") {')
            $stream.WriteLine('        O365site = O365tenant;')
            $stream.WriteLine('    }')
            $stream.WriteLine('    else if (O365site.toLowerCase().indexOf("https://") < 0)')
            $stream.WriteLine('    {')
            $stream.WriteLine('        O365site = (O365tenant + "/sites/" + O365site);')
            $stream.WriteLine('    }')
            $stream.WriteLine('    window.location.href = O365site;')
            $stream.WriteLine('}')
            $stream.WriteLine('</script>')
            $idx..($defaultMaster.Length-1) | % {
                $stream.WriteLine($defaultMaster[$_])
            }
            $stream.close()
        }
        break
    } elseif ($defaultMaster[$idx].Trim().Equals("function O365(O365tenant)")) {
        $exists = $true
    }
    $idx++
}

# Remove X-FRAME OPTIONS
Write-Verbose "Remove X-FRAME Options"
$WebConfigFile = 'C:\inetpub\wwwroot\AAD\WebClient\Web.config'
$WebConfig = [xml](Get-Content $WebConfigFile)
$xframeoptions = $WebConfig.SelectSingleNode("//httpProtocol/customHeaders/add[@name='X-FRAME-OPTIONS']")
if ($xframeoptions) {
    $xframeoptions.ParentNode.RemoveChild($xframeoptions)
    $WebConfig.Save($WebConfigFile)
}

CreateAndUploadApp -SharePointUrl $SharePointUrl `
		           -SharePointInstallFolder $PSScriptRootV2 `
		           -SharePointAdminLoginName $SharePointAdminLoginName `
		           -SharePointAdminPassword $SharePointAdminPassword `
		           -appClientId $appClientId `
		           -appProductId $appProductId `
		           -appSecret $appSecret `
		           -publicWebBaseUrl $publicWebBaseUrl `
		           -SharePointAppCatalogName $SharePointAppCatalogName `
		           -SharePointMultitenant ($SharePointMultitenant -eq "Yes") `
		           -SharePointLanguageFile $LanguageFile

CreatePortal -SharePointInstallFolder $PSScriptRootV2 `
             -SharePointUrl $SharePointUrl `
             -SharePointSite $SharePointSite `
             -SharePointSiteUrl $SharePointSiteUrl `
             -SharePointAdminLoginName $SharePointAdminLoginName `
             -SharePointAdminPassword $SharePointAdminPassword `
		     -appClientId $appClientId `
		     -appFeatureId $appfeatureId `
		     -appProductId $appProductId `
             -SharePointLanguageFile $LanguageFile 

# URLs
$URLsFile = "C:\Users\Public\Desktop\URLs.txt"
"NAV WebClient with AAD auth.  : $PublicWebBaseURL"         | Add-Content -Path $URLsFile
"SharePoint Team Site          : $SharePointSiteUrl"        | Add-Content -Path $URLsFile

if ([Environment]::UserName -ne "SYSTEM") {
    Get-Content $URLsFile | Write-Host -ForegroundColor Yellow
    & notepad.exe $URLsFile
}
