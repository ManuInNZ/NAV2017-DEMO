$PSScriptRootV2 = Split-Path $MyInvocation.MyCommand.Definition -Parent 
Set-StrictMode -Version 2.0
$verbosePreference = 'Continue'
$errorActionPreference = 'Stop'

$HardcodeFile = (Join-Path $PSScriptRootV2 'HardcodeInput.ps1')
if (Test-Path -Path $HardcodeFile) {
    . $HardcodeFile
}
. (Join-Path $PSScriptRootV2 'HelperFunctions.ps1')
. ("c:\program files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1")
Import-Module "C:\NAVDVD\W1\WindowsPowerShellScripts\Cloud\NAVAdministration\NAVAdministration.psm1"
. (Join-Path $PSScriptRootV2 'New-SelfSignedCertificateEx.ps1')

$CustomSettingsConfigFile = 'c:\program files\Microsoft Dynamics NAV\80\Service\CustomSettings.config'
$config = [xml](Get-Content $CustomSettingsConfigFile)
$serverInstance = $config.SelectSingleNode("//appSettings/add[@key='ServerInstance']").value

$regionCodes = @{ 
 "AT" = "de-AT";
 "AU" = "en-AU"; 
 "BE" = "nl-BE";
 "CH" = "de-CH";
 "CZ" = "cs-CZ";
 "DE" = "de-DE";
 "DK" = "da-DK";
 "ES" = "es-ES";
 "FI" = "fi-FI";
 "FR" = "fr-FR";
 "GB" = "en-GB";
 "IS" = "is-IS";
 "IT" = "it-IT";
 "NA" = "en-US";
 "NL" = "nl-NL";
 "NO" = "nb-NO";
 "NZ" = "en-NZ";
 "RU" = "ru-RU";
 "SE" = "sv-SE";
 "W1" = "en-US";
}

$languageCodes = @{ 
 "AT" = "3079";
 "AU" = "3081";
 "BE" = "2067";
 "CH" = "2055";
 "CZ" = "1029";
 "DE" = "1031";
 "DK" = "1030";
 "ES" = "1034";
 "FI" = "1035";
 "FR" = "1036";
 "GB" = "2057";
 "IS" = "1039";
 "IT" = "1040";
 "NA" = "1033";
 "NL" = "1043";
 "NO" = "1044";
 "NZ" = "5129";
 "RU" = "1049";
 "SE" = "1053";
 "W1" = "1033";
}

if (!(Test-Path (Join-Path $PSScriptRootV2 '..\Profiles.ps1'))){

    Import-module SQLPS

    $Languages = ""
    Get-ChildItem 'C:\NAVDVD\*' | Where-Object { $_.PSIsContainer } | % { if ($Languages -eq "") { $Languages = $_.Name } else { $Languages += ", "+$_.Name } }
    $Language = Get-UserInput -Id Language -Text "Please select NAV Language ($Languages)" -Default "W1"
    if ($Language -ne "W1"){

        if (!(Test-Path "C:\NAVDVD\$Language")) {
            throw "Selected language is not available on the VM"
        }

        Set-NAVServerInstance -ServerInstance $serverInstance -Stop

        #Install local DB
        $DatabaseName = "Demo Database NAV (8-0)"
        Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        alter database [$DatabaseName] set single_user with rollback immediate"
        
        Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `
        "USE [master]
        drop database [$DatabaseName]"

        C:

        $bakFile = "C:\NAVDVD\$Language\SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\80\Database\Demo Database NAV (8-0).bak"
        New-NAVDatabase -DatabaseServer localhost -DatabaseInstance NAVDEMO -DatabaseName $DatabaseName -FilePath $bakFile -DestinationPath "C:\Program Files\Microsoft SQL Server\MSSQL12.NAVDEMO\MSSQL\DATA" -Timeout 0

        Set-NAVServerInstance -ServerInstance $serverInstance -Start

        #Install platform files
        Get-ChildItem "C:\NAVDVD\$Language\Installers" | Where-Object { $_.PSIsContainer } | % {
            Get-ChildItem $_.FullName | Where-Object { $_.PSIsContainer } | % {
                $dir = $_.FullName
                Get-ChildItem (Join-Path $dir "*.msi") | % { 
                    Write-Verbose ("Installing "+$_.FullName)
                    Start-Process -FilePath $_.FullName -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
                }
            }
        }

        $regionCode = $regionCodes[$Language]

        $WebConfigFile = "C:\inetpub\wwwroot\$serverInstance\Web.config"
        $WebConfig = [xml](Get-Content $WebConfigFile)
        $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='RegionFormat']").value=$regionCode
        $WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='Language']").value=$regionCode
        $WebConfig.Save($WebConfigFile)

        Set-WinSystemLocale $regionCode
    }
    Copy (Join-Path $PSScriptRootV2 "..\Profiles\$Language.ps1") (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
    . (Join-Path $PSScriptRootV2 '..\Profiles.ps1')

    $languageCode = $languageCodes[$Language]

    Invoke-sqlcmd -ea stop -ServerInstance "localhost\NAVDEMO" -QueryTimeout 0 `    "USE [DEMO Database NAV (8-0)]    UPDATE [dbo].[User Personalization] SET [Language ID]='$languageCode', [Company]='$Company';"    
    C:

} else {
    . (Join-Path $PSScriptRootV2 '..\Profiles.ps1')
}
$languageCode = $languageCodes[$Language]

$vmadmin = $env:USERNAME

$NavAdminUser = Get-UserInput -Id NavAdminUser -Text "NAV administrator username" -Default "admin"
$NavAdminPassword = Get-UserInput -Id NavAdminPassword -Text "NAV administrator password" -Default "P@ssword1"

do
{
    $err = $false
    $CloudServiceName = Get-UserInput -Id CloudServiceName -Text "What is the name of your Cloud-Service" -Default "$env:COMPUTERNAME.cloudapp.net"
    try
    {
        $myIP = Get-MyIp
        $dnsrecord = Resolve-DnsName $CloudServiceName -ErrorAction SilentlyContinue -Type A
        if (!($dnsrecord) -or ($dnsrecord.Type -ne "A") -or ($dnsrecord.IPAddress -ne $myIP)) {
            Write-Host -ForegroundColor Red "That is NOT your Cloud Service Name (Did you name your Cloud Service something different from the Virtual Machine?)"
            Write-Host -ForegroundColor Red "Please find the correct Cloud Service Name in the Azure Management Portal."
            $err = $true
        }
    } 
    catch {}
} while ($err)

# Create http directory
$httpWebSiteDirectory = "C:\inetpub\wwwroot\http"
new-item -Path $httpWebSiteDirectory -ItemType Directory -Force

. (Join-Path $PSScriptRootV2 'Certificate.ps1')

# Grant Access to certificate to user running Service Tier (NETWORK SERVICE)
Grant-AccountAccessToCertificatePrivateKey -CertificateThumbprint $thumbprint -ServiceAccountName "NT AUTHORITY\Network Service"

# Add a NavUserPassword User who is SUPER
$user = Get-NAVServerUser $serverInstance | % { if ($_.UserName -eq $NavAdminUser) { $_ } }
if (!$user) {
    New-NAVServerUser $serverInstance -UserName $NavAdminUser -Password (ConvertTo-SecureString -String $NavAdminPassword -AsPlainText -Force) -ChangePasswordAtNextLogOn:$false -LicenseType Full
    New-NAVServerUserPermissionSet $serverInstance -UserName $NavAdminUser -PermissionSetId "SUPER"
}

# Change configuration
Set-NAVServerConfiguration $serverInstance -KeyName "ServicesCertificateThumbprint" -KeyValue $thumbprint
Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesSSLEnabled" -KeyValue 'true'
Set-NAVServerConfiguration $serverInstance -KeyName "SOAPServicesEnabled" -KeyValue 'true'
Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesSSLEnabled" -KeyValue 'true'
Set-NAVServerConfiguration $serverInstance -KeyName "ODataServicesEnabled" -KeyValue 'true'
Set-NAVServerConfiguration $serverInstance -KeyName "PublicODataBaseUrl" -KeyValue ('https://' +$PublicMachineName + ':7048/' + $serverInstance + '/OData/')
Set-NAVServerConfiguration $serverInstance -KeyName "PublicSOAPBaseUrl" -KeyValue ('https://' + $PublicMachineName + ':7047/' + $serverInstance + '/WS/')
Set-NAVServerConfiguration $serverInstance -KeyName "PublicWebBaseUrl" -KeyValue ('https://' + $PublicMachineName + '/' + $serverInstance + '/WebClient/')
Set-NAVServerConfiguration $serverInstance -KeyName "PublicWinBaseUrl" -KeyValue ('DynamicsNAV://' + $PublicMachineName + ':7046/' + $serverInstance + '/')
Set-NAVServerConfiguration $serverInstance -KeyName "ClientServicesCredentialType" -KeyValue "NavUserPassword"
Set-NAVServerConfiguration $serverInstance -KeyName "ServicesDefaultCompany" -KeyValue $Company

# Restart NAV Service Tier
Set-NAVServerInstance -ServerInstance $serverInstance -Restart

# Expose Web Services
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 9170 -ServiceName Profile          -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 21   -ServiceName Customer         -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 26   -ServiceName Vendor           -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 30   -ServiceName Item             -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 42   -ServiceName SalesOrder       -Published:$true -ErrorAction SilentlyContinue
New-NAVWebService $serverInstance -ObjectType Page -ObjectId 1304 -ServiceName MiniSalesInvoice -Published:$true -ErrorAction SilentlyContinue

# Add firewall rules for SOAP and OData
netsh advfirewall firewall add rule name="Microsoft Dynamics NAV SOAP Services" dir=in action=allow protocol=tcp localport=7047 remoteport=any
netsh advfirewall firewall add rule name="Microsoft Dynamics NAV OData Services" dir=in action=allow protocol=tcp localport=7048 remoteport=any
netsh advfirewall firewall add rule name="Microsoft Dynamics NAV Web Client SSL" dir=in action=allow protocol=tcp localport=443 remoteport=any

# Remove the default IIS WebSite
Remove-DefaultWebSite -ErrorAction SilentlyContinue

# Remove bindings from Web Client
Get-WebBinding -Name "Microsoft Dynamics NAV 2015 Web Client" | Remove-WebBinding

# Add SSL binding to Web Client
New-SSLWebBinding -Name "Microsoft Dynamics NAV 2015 Web Client" -Thumbprint $thumbprint

# Create HTTP site
if (!(Get-Website -Name http)) {
    # Create the web site
    Write-Host "Creating Web Site"
    New-Website -Name http -IPAddress * -Port 80 -PhysicalPath $httpWebSiteDirectory -Force
}
Copy-Item (Join-Path $PSScriptRootV2 'Default.aspx') "$httpWebSiteDirectory\Default.aspx" 
Copy-Item (Join-Path $PSScriptRootV2 'web.config') "$httpWebSiteDirectory\web.config" 

Write-Host "Opening Firewall"
New-FirewallPortAllowRule -RuleName "HTTP access" -Port 80

# Change Web.config
$WebConfigFile = "C:\inetpub\wwwroot\$serverInstance\Web.config"
$WebConfig = [xml](Get-Content $WebConfigFile)
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='HelpServer']").value="$PublicMachineName"
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='DnsIdentity']").value=$dnsidentity
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='ClientServicesCredentialType']").value="NavUserPassword"
$WebConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='Company']").value=$Company
$WebConfig.Save($WebConfigFile)

# Change global ClientUserSettings
$ClientUserSettingsFile = 'C:\Users\All Users\Microsoft\Microsoft Dynamics NAV\80\ClientUserSettings.config'
$ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value= "NavUserPassword"
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='HelpServer']").value= "$PublicMachineName"
$ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value= $dnsidentity
$ClientUserSettings.Save($ClientUserSettingsFile)

# Change vmadmin ClientUserSettings
$ClientUserSettingsFile = "C:\Users\$vmadmin\AppData\Roaming\Microsoft\Microsoft Dynamics NAV\80\ClientUserSettings.config"
if (Test-Path -Path $ClientUserSettingsFile) {
    $ClientUserSettings = [xml](Get-Content $ClientUserSettingsFile)
    $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value= "NavUserPassword"
    $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='HelpServer']").value= "$PublicMachineName"
    $ClientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='DnsIdentity']").value= $dnsidentity
    $ClientUserSettings.Save($ClientUserSettingsFile)
}

$AccountingManager = $Profiles["Accounting Manager"]
$OrderProcessor = $Profiles["Order Processor"]
$SmallBusiness = $Profiles["Small Business"]
New-DesktopShortcut -Name "Run NAV Warmup script"                                -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments 'C:\DEMO\WarmupNAV\WarmupNAV.ps1'
New-DesktopShortcut -Name "NAV 2015 Windows Client"                              -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-Language:$languageCode"
New-DesktopShortcut -Name "NAV 2015 Win Order Processor"                         -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-Language:$languageCode -Profile:""$OrderProcessor"""
New-DesktopShortcut -Name "NAV 2015 Win Accounting Manager"                      -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\Microsoft.Dynamics.Nav.Client.exe" -Arguments "-Language:$languageCode -Profile:""$AccountingManager"""
New-DesktopShortcut -Name "NAV 2015 Web Client"                                  -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2015 Web Small Business"                          -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/?profile=$SmallBusiness" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2015 Web Accounting Manager"                      -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/?profile=$AccountingManager" -IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2015 Tablet Client"                               -TargetPath "https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx" IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"
New-DesktopShortcut -Name "NAV 2015 Development Environment"                     -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe" -Arguments "servername=localhost\NAVDEMO, database=Demo Database NAV (8-0), ntauthentication=1"
New-DesktopShortcut -Name "NAV 2015 Administration"                              -TargetPath "C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\Microsoft Dynamics NAV Server.msc" -IconLocation "%SystemRoot%\Installer\{00000000-0000-8000-0000-0CE90DA3512B}\AdminToolsIcon.exe"
New-DesktopShortcut -Name "NAV 2015 Administration Shell"                        -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments "-NoExit -ExecutionPolicy RemoteSigned & 'C:\Program Files\Microsoft Dynamics NAV\80\Service\NavAdminTool.ps1'"
New-DesktopShortcut -Name "NAV 2015 Development Shell"                           -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell.exe" -Arguments "-NoExit -ExecutionPolicy RemoteSigned & 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\NavModelTools.ps1'"
New-DesktopShortcut -Name "Windows Powershell ISE"                               -TargetPath "C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe" -WorkingDirectory "C:\DEMO"
New-DesktopShortcut -Name "Welcome to Microsoft Dynamics NAV on Microsoft Azure" -TargetPath "C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht"
New-DesktopShortcut -Name "NAV 2015 Demo Environment Landing Page"               -TargetPath "http://$PublicMachineName" IconLocation "C:\Program Files\Internet Explorer\iexplore.exe, 3"

#Load the dll
Add-Type -Path (Join-Path $PSScriptRootV2 'Microsoft.Search.Interop.dll')
#Create an instance of CSearchManagerClass
$sm = New-Object Microsoft.Search.Interop.CSearchManagerClass 
#Next we connect to the SystemIndex catalog
$catalog = $sm.GetCatalog("SystemIndex")
#Get the interface to the scope rule manager
$crawlman = $catalog.GetCrawlScopeManager()
$crawlman.AddUserScopeRule("file:///C:\inetpub\wwwroot\DynamicsNAV80Help\help\en\*", $true, $false, $null)
$crawlman.SaveAll()

#Update .mht file in DEMO folder
$mht = [System.IO.File]::ReadAllText("C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht", [System.Text.Encoding]::GetEncoding(28591))
$orgWebClientLink = "http://localhost:8080/NAV/WebClient"
$newWebClientLink = "https://$PublicMachineName/$serverInstance/WebClient"
$mht = $mht.Replace($orgWebClientLink, $newWebClientLink)
[System.IO.File]::WriteAllText("C:\DEMO\Welcome to Microsoft Dynamics NAV on Microsoft Azure.mht", $mht, [System.Text.Encoding]::GetEncoding(28591))

$URLsFile = "C:\Users\Public\Desktop\URLs.txt""Web Client URL                : https://$PublicMachineName/$serverInstance/WebClient"               | Add-Content -Path $URLsFile
"Tablet Client URL             : https://$PublicMachineName/$serverInstance/WebClient/tablet.aspx"   | Add-Content -Path $URLsFile
("SOAP Services URL            : https://$PublicMachineName" + ":7047/$serverInstance/WS/Services")  | Add-Content -Path $URLsFile
("OData Services URL           : https://$PublicMachineName" + ":7048/$serverInstance/OData/")       | Add-Content -Path $URLsFile
"NAV Admin Username            : $NAVAdminUser"                                                      | Add-Content -Path $URLsFile
"NAV Admin Password            : $NAVAdminPassword"                                                  | Add-Content -Path $URLsFile

# Turn off IE Enhanced Security Configuration
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0

if ([Environment]::UserName -ne "SYSTEM") {
    Get-Content $URLsFile | Write-Host -ForegroundColor Yellow

    # Show landing page
    Start-Process "http://$PublicMachineName"
}