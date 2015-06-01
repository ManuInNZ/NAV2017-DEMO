$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Inquire'

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

$WebConfigFile = "C:\inetpub\wwwroot\$ServerInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
$WebClientRegionFormat = $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='RegionFormat']").Value

. (Join-Path $PSScriptRootV2 "WordReportingTranslations\$WebClientRegionFormat.ps1")

if (!($publicSoapBaseUrl)) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}

if ($multitenant -ne "false") {
    while ($true) { throw "Server is multi-tenant, Word Reporting must be installed before multitenancy" }
}

# Import NAV Objects
Write-Verbose "Import NAV Objects"
$NavIde = 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'
Import-NAVApplicationObject -Path (Join-Path $PSScriptRootV2 "WordReporting.fob") -NavServerInstance $serverInstance -DatabaseServer 'localhost\NAVDEMO' -DatabaseName 'Demo Database NAV (8-0)' -ImportAction Overwrite -Confirm:$false -SynchronizeSchemaChanges Force

# Restart Service Tier
Write-Verbose "Restart Service Tier"
Set-NAVServerInstance $ServerInstance -Restart

# Expose Web Service
Write-Verbose "Expose Web Service"
New-NAVWebService $serverInstance -ObjectType Codeunit -ObjectId 50500 -ServiceName WordReportingSetup -Published:$true -ErrorAction SilentlyContinue

$WrdRepUsername = "wrdrepuser"
$WrdRepPassword = "wrpP@ssw0rd"
if (!(Get-NAVServerUser $serverInstance | Where-Object { $_.UserName -eq $WrdRepUsername })) {
    Write-Verbose "Create Word Reporting user"
    New-NAVServerUser -ServerInstance $serverInstance -UserName $WrdRepUsername -Password (ConvertTo-SecureString -String $WrdRepPassword -AsPlainText -Force) 
    New-NAVServerUserPermissionSet -ServerInstance $serverInstance -UserName $WrdRepUsername -PermissionSetId SUPER
} else {
    Write-Verbose "Enable Word Reporting user"
    Set-NAVServerUser $serverInstance -UserName $WrdRepUsername -State Enabled
}

# Invoke Web Service
Write-Verbose "Create Web Service Proxy"
$secureWrdRepPassword = ConvertTo-SecureString -String $WrdRepPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($WrdRepUsername, $secureWrdRepPassword)
$Uri = ("$publicSoapBaseUrl" + "$Company/Codeunit/WordReportingSetup")
$proxy = New-WebServiceProxy -Uri $Uri -Credential $credential
# Timout 1 hour
$proxy.timeout = 60*60*1000
Write-Verbose "Setup Word Reporting demo"
$ModernLayoutID   = $proxy.ImportCustomReportLayout(1306, $Modern,   (Get-LayoutFilename -Folder $PSScriptRootV2 -Language $Language -Filename 'Modern.docx'));
$RedLayoutID      = $proxy.ImportCustomReportLayout(1306, $Red,      (Get-LayoutFilename -Folder $PSScriptRootV2 -Language $Language -Filename 'Red.docx'));
$TimelessLayoutID = $proxy.ImportCustomReportLayout(1306, $Timeless, (Get-LayoutFilename -Folder $PSScriptRootV2 -Language $Language -Filename 'Timeless.docx'));
$proxy.SetupWordReportingDemo(1306, $ModernLayoutID);

Write-Verbose "Disable Word Reporting user"
Set-NAVServerUser $Serverinstance -UserName $WrdRepUsername -State Disabled
Get-NAVServerSession -ServerInstance $serverInstance | % { Remove-NAVServerSession -ServerInstance $serverInstance -SessionId $_.SessionID -Force }
