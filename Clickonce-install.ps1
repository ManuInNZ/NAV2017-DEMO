$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Stop'

. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
Import-Module WebAdministration
. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')

$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$thumbprint = $config.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").value
$PublicMachineName = $config.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").value.Split('/')[2].ToLower()
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value

if (!$thumbprint) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}

if ($multitenant -ne "false") {
    while ($true) { throw "Server is multi-tenant, cannot apply this package." }
}

$httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
Remove-Item "$httpWebSiteDirectory\NAV" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$httpWebSiteDirectory\ADD" -Force -Recurse -ErrorAction SilentlyContinue

Write-Verbose "Deploying ClickOnce with NavUserPassword authentication"
New-ClickOnceDeployment -Name NAV -PublicMachineName $PublicMachineName -clickOnceWebSiteDirectory $httpWebSiteDirectory

if (Get-NAVWebServerInstance -WebServerInstance AAD) {
    Write-Verbose "Deploying ClickOnce with AAD authentication"
    New-ClickOnceDeployment -Name AAD -PublicMachineName $PublicMachineName -clickOnceWebSiteDirectory $httpWebSiteDirectory
}

$URLsFile = "C:\Users\Public\Desktop\URLs.txt""ClickOnce with User/Pswd auth.: http://$PublicMachineName/NAV"     | Add-Content -Path $URLsFile
if (Get-NAVWebServerInstance -WebServerInstance AAD) {
    "ClickOnce with AAD auth.      : http://$PublicMachineName/AAD" | Add-Content -Path $URLsFile
}

#Get-Content $URLsFile | Write-Host -ForegroundColor Yellow

#& notepad.exe $URLsFile
