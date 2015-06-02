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
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"

$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value
$publicSoapBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").value
$publicODataBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicODataBaseUrl']").value
$PublicWebBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").value

$WebConfigFile = "C:\inetpub\wwwroot\$ServerInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
$WebClientRegionFormat = $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='RegionFormat']").Value

if (!($publicSoapBaseUrl)) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}

if ($multitenant -ne "false") {
    while ($true) { throw "Server is multi-tenant, Bingmaps demo package must be installed before multitenancy" }
}

$BingMapsKey = Get-UserInput -Id BingMapsKey -Text "Bing Maps Key (http://msdn.microsoft.com/en-us/library/ff428642.aspx)"
Set-Content -Path "C:\DEMO\BingMaps\BingMapsKey.txt" -Value $BingMapsKey

# Import NAV Objects
Write-Verbose "Import NAV Objects"
$NavIde = 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'
Import-NAVApplicationObject -Path (Join-Path $PSScriptRootV2 "Fobs\$Language.fob") -NavServerInstance $serverInstance -DatabaseServer 'localhost\NAVDEMO' -DatabaseName 'Demo Database NAV (8-0)' -ImportAction Overwrite -Confirm:$false -SynchronizeSchemaChanges Force
Copy-Item (Join-Path $PSScriptRootV2 "Translations") "C:\Program Files\Microsoft Dynamics NAV\80\Service" -Recurse -Force

$wsusername = 'webserviceuser'
$user = get-navserveruser $serverInstance | where-object { $_.UserName -eq $wsusername }
if (!($user)){
    new-navserveruser $serverInstance -UserName $wsusername -CreateWebServicesKey -LicenseType External
    New-NAVServerUserPermissionSet $serverInstance -UserName $wsusername -PermissionSetId SUPER
    $user = get-navserveruser $serverInstance | where-object { $_.UserName -eq $wsusername }
}

$mkt = "&mkt=$WebClientRegionFormat,en-US"
$maphtml = Get-Content -Path (Join-Path $PSScriptRootV2 "map.aspx")
$maphtml = $maphtml.Replace('<mkt>',$mkt).Replace('<BingMapsKey>', $BingMapsKey).Replace('<PublicODataBaseUrl>',$PublicODataBaseUrl).Replace('<WSUsername>', $wsusername).Replace('<WSKey>',$user.WebServicesKey);
Set-Content -Path "C:\Program Files\Microsoft Dynamics NAV\80\Web Client\map.aspx" -Value $maphtml

# Copy Client Add-ins
Write-Verbose "Copy Client Add-ins"
XCopy (Join-Path $PSScriptRootV2 "Client Add-Ins\*.*") "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\Add-ins" /Y

# Restart Service Tier
Write-Verbose "Restart Service Tier"
Set-NAVServerInstance $ServerInstance -Restart

# Expose Web Service
Write-Verbose "Expose Web Service"
New-NAVWebService $serverInstance -ObjectType Codeunit -ObjectId 52001 -ServiceName BingMapsSetup    -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page     -ObjectId 52001 -ServiceName CustomerLocation -Published:$true -ErrorAction SilentlyContinue

$GeocodeUsername = "geocodeuser"
$GeocodePassword = "gcdP@ssw0rd"
if (!(Get-NAVServerUser $serverInstance | Where-Object { $_.UserName -eq $geocodeUsername })) {
    Write-Verbose "Create Geocode user"
    New-NAVServerUser -ServerInstance $serverInstance -UserName $GeocodeUsername -Password (ConvertTo-SecureString -String $GeocodePassword -AsPlainText -Force) 
    New-NAVServerUserPermissionSet -ServerInstance $serverInstance -UserName $GeocodeUsername -PermissionSetId SUPER
} else {
    Write-Verbose "Enable Geocode user"
    Set-NAVServerUser $serverInstance -UserName $geocodeUsername -State Enabled
}

# Invoke Web Service
Write-Verbose "Create Web Service Proxy"
$secureGeocodePassword = ConvertTo-SecureString -String $GeocodePassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($GeocodeUsername, $secureGeocodePassword)
$Uri = ("$publicSoapBaseUrl" + "$Company/Codeunit/BingMapsSetup")
$proxy = New-WebServiceProxy -Uri $Uri -Credential $credential
# Timout 1 hour
$proxy.timeout = 60*60*1000
Write-Verbose "Geocode all customers"
$proxy.GeocodeAll()
Write-Verbose "Register Client Add-in"
$proxy.RegisterClientAddIn('BingMapsControl', '6b29a4991d2c0322', 'Bing Maps Control Add-In', 'C:\DEMO\BingMaps\BingMapsScriptControlAddIn\Resources\manifest.zip');

Write-Verbose "Disable Geocode user"
Set-NAVServerUser $Serverinstance -UserName $GeocodeUsername -State Disabled
Get-NAVServerSession -ServerInstance $serverInstance | % { Remove-NAVServerSession -ServerInstance $serverInstance -SessionId $_.SessionID -Force }

$URLsFile = "C:\Users\Public\Desktop\URLs.txt"

Get-Location | Add-Content  -Path $URLsFile

('Customer MAP User/Pswd. auth. : '+$PublicWebBaseUrl+'map.aspx')      | Add-Content -Path $URLsFile
if (Test-Path 'C:\inetpub\wwwroot\AAD' -PathType Container) {
    $AADUrl = $PublicWebBaseUrl.Replace('/NAV/','/AAD/')
    ('Customer MAP with AAD auth.   : '+$AADUrl+'map.aspx')            | Add-Content -Path $URLsFile
}

if ([Environment]::UserName -ne "SYSTEM") {
    Get-Content $URLsFile | Write-Host -ForegroundColor Yellow
    & notepad.exe $URLsFile
}
