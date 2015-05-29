function New-DesktopShortcut
{
	Param
	(
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
		[string]$TargetPath,
		[Parameter(Mandatory=$false)]
		[string]$WorkingDirectory,
		[Parameter(Mandatory=$false)]
		[string]$IconLocation,
		[Parameter(Mandatory=$false)]
		[string]$Arguments
	)

    $filename = "C:\Users\Public\Desktop\$Name.lnk"
    if (!(Test-Path -Path $filename)) {
        $Shell =  New-object -comobject WScript.Shell
        $Shortcut = $Shell.CreateShortcut($filename)
        $Shortcut.TargetPath = $TargetPath
        if (!$WorkingDirectory) {
            $WorkingDirectory = Split-Path $TargetPath
        }
        $Shortcut.WorkingDirectory = $WorkingDirectory
        if ($Arguments) {
            $Shortcut.Arguments = $Arguments
        }
        if ($IconLocation) {
            $Shortcut.IconLocation = $IconLocation
        }
        $Shortcut.save()
    }
}

function New-ClickOnceDeployment
{
    param (
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(Mandatory=$true)]
        [string]$PublicMachineName,
        [parameter(Mandatory=$true)]
        [string]$TenantID,
        [parameter(Mandatory=$true)]
        [string]$clickOnceWebSiteDirectory
    )

    $clickOnceDirectory = Join-Path $clickOnceWebSiteDirectory $Name
    $webSiteUrl = ("http://" + $PublicMachineName + "/" + $Name)

    $clientUserSettingsFileName = Join-Path $env:ProgramData "Microsoft\Microsoft Dynamics NAV\80\ClientUserSettings.config"
    [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='Server']").value=$PublicMachineName
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='TenantId']").value=$TenantID
    $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ServicesCertificateValidationEnabled']").value="false"


    if ($Name -eq 'AAD') {
        [xml]$webConfig = Get-Content 'C:\inetpub\wwwroot\AAD\web.config'
        $ACSUri = ($webConfig.SelectSingleNode("//configuration/DynamicsNAVSettings/add[@key='ACSUri']").value + "%26wreply=https://$PublicMachineName/AAD/WebClient")
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ACSUri']").value = $ACSUri
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key='ClientServicesCredentialType']").value = 'AccessControlService'        
    }

    $applicationName = "Microsoft Dynamics NAV 2015 Windows Client for $PublicMachineName ($Name)"
    $applicationPublisher = "Microsoft Corporation"
    
    New-ClickOnceDirectory -ClickOnceDirectory $clickOnceDirectory -ClientUserSettings $clientuserSettings

    $MageExeLocation = Join-Path $PSScriptRoot 'mage.exe'
    
    $clickOnceApplicationFilesDirectory = Join-Path $clickOnceDirectory 'Deployment\ApplicationFiles'

    # Remove more unnecessary stuff
    Get-ChildItem $clickOnceApplicationFilesDirectory -include '*.etx' -Recurse | Remove-Item
    Get-ChildItem $clickOnceApplicationFilesDirectory -include '*.stx' -Recurse | Remove-Item
    Get-ChildItem $clickOnceApplicationFilesDirectory -include '*.chm' -Recurse | Remove-Item
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'SLT') -force -Recurse -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'NavModelTools.ps1') -force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'ClientUserSettings.lnk') -force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'Microsoft.Dynamics.Nav.Model.Tools.*') -force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'Microsoft.Dynamics.Nav.Ide.psm1') -force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $clickOnceApplicationFilesDirectory 'Cronus.flf') -force -ErrorAction SilentlyContinue
    
    $applicationManifestFile = Join-Path $clickOnceApplicationFilesDirectory 'Microsoft.Dynamics.Nav.Client.exe.manifest'
    $applicationIdentityName = "$PublicMachineName ClickOnce $Name"
    $applicationIdentityVersion = '8.0.1.0'
    
    Set-ApplicationManifestFileList `
        -ApplicationManifestFile $ApplicationManifestFile `
        -ApplicationFilesDirectory $ClickOnceApplicationFilesDirectory `
        -MageExeLocation $MageExeLocation
    Set-ApplicationManifestApplicationIdentity `
        -ApplicationManifestFile $ApplicationManifestFile `
        -ApplicationIdentityName $ApplicationIdentityName `
        -ApplicationIdentityVersion $ApplicationIdentityVersion
    
    $deploymentManifestFile = Join-Path $clickOnceDirectory 'Deployment\Microsoft.Dynamics.Nav.Client.application'
    $deploymentIdentityName = "$PublicMachineName ClickOnce $Name"
    $deploymentIdentityVersion = '8.0.1.0'
    $deploymentManifestUrl = ($webSiteUrl + "/Deployment/Microsoft.Dynamics.Nav.Client.application")
    $applicationManifestUrl = ($webSiteUrl + "/Deployment/ApplicationFiles/Microsoft.Dynamics.Nav.Client.exe.manifest")
    
    Set-DeploymentManifestApplicationReference `
        -DeploymentManifestFile $DeploymentManifestFile `
        -ApplicationManifestFile $ApplicationManifestFile `
        -ApplicationManifestUrl $ApplicationManifestUrl `
        -MageExeLocation $MageExeLocation
    Set-DeploymentManifestSettings `
        -DeploymentManifestFile $DeploymentManifestFile `
        -DeploymentIdentityName $DeploymentIdentityName `
        -DeploymentIdentityVersion $DeploymentIdentityVersion `
        -ApplicationPublisher $ApplicationPublisher `
        -ApplicationName $ApplicationName `
        -DeploymentManifestUrl $DeploymentManifestUrl
    
    # Put a web.config file in the root folder, which will tell IIS which .html file to open
    $sourceFile = Join-Path $PSScriptRoot 'root_web.config'
    $targetFile = Join-Path $clickOnceDirectory 'web.config'
    Copy-Item $sourceFile -destination $targetFile
    
    # Put a web.config file in the Deployment folder, which will tell IIS to allow downloading of .config files etc.
    $sourceFile = Join-Path $PSScriptRoot 'deployment_web.config'
    $targetFile = Join-Path $clickOnceDirectory 'Deployment\web.config'
    Copy-Item $sourceFile -destination $targetFile
}

$cons = 'bcdfghjklmnpqrstvwxz'
$voc = 'aeiouy'
$numbers = '0123456789'

function randomchar([string]$str)
{
    $rnd = Get-Random -Maximum $str.length
    [string]$str[$rnd]
}

Function new-RandomPassword {
    ((randomchar $cons).ToUpper() + `
     (randomchar $voc) + `
     (randomchar $cons) + `
     (randomchar $voc) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers) + `
     (randomchar $numbers))
}
