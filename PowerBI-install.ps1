$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Inquire'

$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}

. (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"

$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$publicSoapBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicSOAPBaseUrl']").value

if (!($publicSoapBaseUrl)) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}

if ($multitenant -ne "false") {
    while ($true) { throw "Server is multi-tenant, PowerBI demo package must be installed before multitenancy" }
}

# Import NAV Objects
Write-Verbose "Import NAV Objects"
$NavIde = 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'
Import-NAVApplicationObject -Path (Join-Path $PSScriptRootV2 "PowerBI.fob") -NavServerInstance $serverInstance -DatabaseServer 'localhost\NAVDEMO' -DatabaseName 'Demo Database NAV (8-0)' -ImportAction Overwrite -Confirm:$false -SynchronizeSchemaChanges Force

# Restart Service Tier
Write-Verbose "Restart Service Tier"
Set-NAVServerInstance $ServerInstance -Restart

# Expose Web Service
Write-Verbose "Expose Web Service"
New-NAVWebService $serverInstance -ObjectType Query -ObjectId 50000 -ServiceName CustomerAnalysis -Published:$true
New-NAVWebService $serverInstance -ObjectType Query -ObjectId 50001 -ServiceName Product          -Published:$true
New-NAVWebService $serverInstance -ObjectType Query -ObjectId 50002 -ServiceName SalesInvoiceLine -Published:$true
New-NAVWebService $serverInstance -ObjectType Page  -ObjectId    14 -ServiceName SalesPeople      -Published:$true

# Show Blog post about PowerBI
Start-Process "http://blogs.msdn.com/b/nav/archive/2015/03/27/powerbi-com-and-microsoft-dynamics-nav-2015.aspx"