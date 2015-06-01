$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 

Set-StrictMode -Version 2.0
$verbosePreference = 'SilentlyContinue'
$errorActionPreference = 'Inquire'

$SharePointInstallFolder = ""
$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}

. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
. ("C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
Import-module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
if ($SharePointInstallFolder) {
    . (Join-Path $SharePointInstallFolder '..\Profiles.ps1')
    . (Join-Path $SharePointInstallFolder 'createportal.ps1')
    . (Join-Path $SharePointInstallFolder 'HelperFunctions.ps1')
    Import-module (Join-Path $SharePointInstallFolder 'NavInO365.dll')
    Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\NAVOffice365Administration\NAVOffice365Administration.psm1"
}

function New-DemoTenant
{
	Param
	(
		[Parameter(Mandatory=$True)]
		[string]$TenantID
    )

    $httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
    $CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
    $config = [xml](Get-Content $CustomSettingsConfigFile)
    $multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value
    $WebClientBaseUrl = $config.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").value
    $serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
    $PublicMachineName = $WebClientBaseUrl.Split('/')[2]

    if ($multitenant -eq 'false') {
        Write-Host -ForegroundColor Red "System not setup for multi tenancy"
    } else {
        Write-Host -ForegroundColor Yellow "Restoring tenant template Database"
        New-NAVDatabase -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName $TenantID -ServiceAccount "NT AUTHORITY\Network Service" -Timeout 0 -FilePath 'C:\MT\template.bak' -DestinationPath "C:\MT\$TenantID"

        # Change Tenant Id in Database
        Invoke-sqlcmd -ea stop ('update [' + $TenantID + '].[dbo].[$ndo$tenantproperty] set tenantid = ''' + $TenantID + ''';')

        Write-Host -ForegroundColor Yellow "Mounting tenant"
        if ($SharePointInstallFolder) {
            $SharePointSiteUrl = "$SharePointUrl/sites/$TenantID"
            Mount-NAVTenant -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName $TenantID -ServerInstance $serverInstance -Id $TenantID -AlternateId @($SharePointSiteUrl)
        } else {
            Mount-NAVTenant -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName $TenantID -ServerInstance $serverInstance -Id $TenantID
        }
        Write-Host -ForegroundColor Yellow "Synchronizing tenant"
        Sync-NAVTenant -Tenant $TenantID -Mode ForceSync -ServerInstance $serverInstance -Force
        Write-Host -ForegroundColor Yellow "Creating Click-Once manifest"
        New-ClickOnceDeployment -Name $TenantID -PublicMachineName $PublicMachineName -TenantID $TenantID -clickOnceWebSiteDirectory $httpWebSiteDirectory
        Add-Content -Path  "$httpWebSiteDirectory\tenants.txt" -Value $TenantID

        if ($SharePointInstallFolder) {
            Write-Host -ForegroundColor Yellow "Creating SharePoint Portal"
            CreatePortal -SharePointInstallFolder $SharePointInstallFolder `
                         -SharePointUrl $SharePointUrl `
                         -SharePointSite $TenantID `
                         -SharePointSiteUrl $SharePointSiteUrl `
                         -SharePointAdminLoginName $SharePointAdminLoginName `
                         -SharePointAdminPassword $SharePointAdminPassword `
            		     -appClientId $SharePointAppClientId `
            		     -appFeatureId $SharePointAppfeatureId `
            		     -appProductId $SharePointAppProductId `
                         -SharePointLanguageFile $SharePointLanguageFile 
        }

        Write-Host 

        $URLsFile = ("C:\MT\$TenantID\URLs.txt")        "Web Client URL                : https://$PublicMachineName/$ServerInstance/WebClient?tenant=$TenantID"             | Add-Content -Path $URLsFile
        "Tablet Client (browser) URL   : https://$PublicMachineName/$ServerInstance/WebClient/tablet.aspx?tenant=$TenantID" | Add-Content -Path $URLsFile
       ("Tablet Client (device) URL    : https://$PublicMachineName/$ServerInstance"+"?tenant=$TenantID")                   | Add-Content -Path $URLsFile
       ("Tablet Client (configure) URL : ms-dynamicsnav://$PublicMachineName/$ServerInstance"+"?tenant=$TenantID")          | Add-Content -Path $URLsFile
        "Windows Client (local) URL    : dynamicsnav://///?tenant=$TenantID"                                                | Add-Content -Path $URLsFile
        "Windows Client (clickonce) URL: http://$PublicMachineName/$TenantID"                                               | Add-Content -Path $URLsFile
        Get-NavServerUser $serverInstance -Tenant $TenantID | % {
            $NewPassword = New-RandomPassword
            $UserName = $_.UserName
            Set-NavServerUser $serverInstance -Tenant $TenantId -UserName $UserName -Password (ConvertTo-SecureString -String $NewPassword -AsPlainText -Force)
            "User                          : $UserName / $NewPassword"                                                      | Add-Content -Path $URLsFile
        }

        Get-Content $URLsFile | Write-Host -ForegroundColor Yellow
    }
}

function Remove-DemoTenant
{
	Param
	(
		[Parameter(Mandatory=$True)]
		[string]$TenantID
    )

    $httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
    $CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
    $config = [xml](Get-Content $CustomSettingsConfigFile)
    $serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
    $multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value

    if ($multitenant -eq 'false') {
        Write-Host -ForegroundColor Red "System not setup for multi tenancy"
    } else {
        Write-Host -ForegroundColor Yellow "Dismounting tenant"
        Dismount-NAVTenant -ServerInstance $serverInstance -Tenant $TenantID -Force
        Write-Host -ForegroundColor Yellow "Removing Database"
        Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        alter database [$TenantID] set single_user with rollback immediate;
        drop database [$TenantID];"
        Set-Location $PSScriptRoot
        Remove-Item "C:\MT\$TenantID" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $httpWebSiteDirectory $TenantID) -Recurse -Force -ErrorAction SilentlyContinue
        
        $tenants = Get-Content -Path "$httpWebSiteDirectory\tenants.txt"
        Clear-Content -Path "$httpWebSiteDirectory\tenants.txt"
        $tenants | % {
            if ($_ -ne $TenantID) {
                Add-Content -Path "$httpWebSiteDirectory\tenants.txt" -Value $_
            }
        }

        Write-Host -ForegroundColor Yellow "Done"
    }
}

Function Get-DemoTenantList {
    $CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
    $config = [xml](Get-Content $CustomSettingsConfigFile)
    $serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value
    $multitenant = $config.SelectSingleNode("//appSettings/add[@key='Multitenant']").value

    if ($multitenant -eq 'false') {
        Write-Host -ForegroundColor Red "System not setup for multi tenancy"
    } else {
        get-navtenant $serverInstance | % { $_.Id }
    }
}

Export-ModuleMember -Function "New-DemoTenant", "Remove-DemoTenant", "Get-DemoTenantList"
