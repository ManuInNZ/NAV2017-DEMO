$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Stop'

$SharePointInstallFolder = ""
$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}

. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"

$httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
$PublicWebBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").value
$PublicMachineName = $PublicWebBaseUrl.Split('/')[2]
$thumbprint = $config.SelectSingleNode("//appSettings/add[@key='ServicesCertificateThumbprint']").value

if (!$thumbprint) {
    while ($true) { throw "You need to run the initialize Server script before applying demo packages." }
}

if (Test-Path 'C:\inetpub\wwwroot\AAD' -PathType Container) {
    if (!$SharePointInstallFolder) {
        while ($true) { throw "When installing O365 integration you answered NO to the question on whether you were going to install multi-tenancy." }
    }
}

if (Test-Path (Join-Path $httpWebSiteDirectory $serverInstance)) {
    while ($true) { throw "You cannot apply Multitenancy pack after ClickOnce pack" }
}

if ($multitenant -eq 'false') {
    clear

    Set-NAVServerInstance $serverInstance -Stop

    Export-NAVApplication -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName "DEMO Database NAV (8-0)" -DestinationDatabaseName "App DEMO Database NAV (8-0)" -ServiceAccount "NT AUTHORITY\Network Service"
    Set-NAVServerConfiguration $serverInstance -KeyName DatabaseName -KeyValue ""
    Set-NAVServerInstance $serverInstance -Start

    Mount-NAVApplication $serverInstance -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName "App DEMO Database NAV (8-0)" -Force

    # Change Tenant Id in Database
    Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 ('update [DEMO Database NAV (8-0)].[dbo].[$ndo$tenantproperty] set tenantid = ''default'';')

    if ($SharePointInstallFolder) {
        Mount-NAVTenant $serverInstance -Id default -AllowAppDatabaseWrite -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName "DEMO Database NAV (8-0)" -AlternateId @("$SharePointUrl/sites/default")
    } else {
        Mount-NAVTenant $serverInstance -Id default -AllowAppDatabaseWrite -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName "DEMO Database NAV (8-0)"
    }


    Set-Content -Path  "$httpWebSiteDirectory\tenants.txt" -Value "default"

    # Change global ClientUserSettings
    $ClientUserSettingsFile = 'C:\Users\All Users\Microsoft\Microsoft Dynamics NAV\80\ClientUserSettings.config'
    $ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
    $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='TenantId']").value= "Default"
    $ClientUserSettings.Save($ClientUserSettingsFile)
    
    $vmadmin = $env:USERNAME

    # Change vmadmin ClientUserSettings
    $ClientUserSettingsFile = "C:\Users\$vmadmin\AppData\Roaming\Microsoft\Microsoft Dynamics NAV\80\ClientUserSettings.config"
    if (Test-Path -Path $ClientUserSettingsFile) {
        $ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
        $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='TenantId']").value= "Default"
        $ClientUserSettings.Save($ClientUserSettingsFile)
    }

    # Remove Old Web Client
    get-item C:\Users\Public\Desktop\*.lnk | % {
        $Shell =  New-object -comobject WScript.Shell
        $lnk = $Shell.CreateShortcut($_.FullName)
        if ($lnk.TargetPath -eq "") {
            Remove-Item $_.FullName
        }
    }

    New-ClickOnceDeployment -Name default -PublicMachineName $PublicMachineName -TenantID default -clickOnceWebSiteDirectory $httpWebSiteDirectory

    New-DesktopShortcut -Name "NAV 2015 Web Client"               -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/?tenant=Default" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    New-DesktopShortcut -Name "NAV 2015 Tablet Client"            -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx?tenant=Default" IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
    $DemoAdminShell = Join-Path $PSScriptRootV2 'MTDemoAdminShell.ps1'
    New-DesktopShortcut -Name "Multitenancy Demo Admin Shell"     -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments "-NoExit & '$DemoAdminShell'"

    New-Item 'C:\MT' -ItemType Directory -Force
    $bakfile = 'C:\MT\template.bak'
    Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        BACKUP DATABASE [DEMO Database NAV (8-0)] TO  DISK = N'$bakfile' WITH INIT"
    cd $PSScriptRootV2
}

$URLsFile = "C:\Users\Public\Desktop\URLs.txt"$URLs = Get-Content $URLsFile

"Web Client URL                : https://$PublicMachineName/$serverInstance/WebClient?tenant=default"             | Set-Content -Path $URLsFile
"Tablet Client URL             : https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx?tenant=default" | Add-Content -Path $URLsFile

if ($SharePointInstallFolder) {
    "Web Client URL (AAD)          : https://$PublicMachineName/AAD/WebClient?tenant=default"             | Add-Content -Path $URLsFile
    "Tablet Client URL (AAD)       : https://$PublicMachineName/AAD/WebClient/tablet.aspx?tenant=default" | Add-Content -Path $URLsFile
}

$URLs | % { if ($_.StartsWith("NAV Admin")) { $_ | Add-Content -Path $URLsFile } }

"Please open Multitenancy Demo Admin Shell on the desktop to add or remove tenants" | Add-Content -Path $URLsFile

if ([Environment]::UserName -ne "SYSTEM") {
    Get-Content $URLsFile | Write-Host -ForegroundColor Yellow
    & notepad.exe $URLsFile
}
