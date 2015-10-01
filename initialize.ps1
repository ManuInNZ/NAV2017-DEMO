#usage initialize.ps1

param
(
       [string]$VMAdminUsername = $null
      ,[string]$VMAdminPassword  = $null
      ,[string]$Country = $null
      ,[string]$PublicMachineName = $null
      ,[string]$multitenancy = $null
      ,[string]$bingMapsKey = $null
      ,[string]$clickonce = $null
      ,[string]$powerBI = $null
      ,[string]$Office365UserName = $null
      ,[string]$Office365Password = $null
)

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force
Start-Transcript -Path "C:\DEMO\initialize.txt"

Set-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$VMAdminUsername   = ''' + $VMAdminUsername + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$VMAdminPassword   = ''' + $VMAdminPassword + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$Country           = ''' + $Country + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$PublicMachineName = ''' + $PublicMachineName + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$multitenancy      = ''' + $multitenancy + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$bingMapsKey       = ''' + $bingMapsKey + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$clickonce         = ''' + $clickonce + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$powerBI           = ''' + $powerBI + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$Office365UserName = ''' + $Office365UserName + '''')
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$Office365Password = ''' + $Office365Password + '''')

# Other variables
$NavAdminUser = "admin"
$NavAdminPassword = $VMAdminPassword
$CloudServiceName = $PublicMachineName
$MachineName = [Environment]::MachineName.ToLowerInvariant()

$error = $false

try {
    # Initialize Virtual Machine
    ('$HardcodeLanguage = "'+$Country.Substring(0,2)+'"')      | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    ('$HardcodeNavAdminUser = "'+$NAVAdminUser+'"')            | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    ('$HardcodeNavAdminPassword = "'+$NAVAdminPassword+'"')    | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    ('$HardcodeCloudServiceName = "'+$CloudServiceName+'"')    | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    ('$HardcodePublicMachineName = "'+$PublicMachineName+'"')  | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    ('$HardcodecertificatePfxFile = "default"')                | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
    . 'c:\DEMO\Initialize\install.ps1' 4> 'C:\DEMO\Initialize\install.log'
} catch {
    Set-Content -Path "c:\DEMO\initialize\error.txt" -Value $_.Exception.Message
    Write-Verbose $_.Exception.Message
    throw
}

Set-Content -Path "c:\inetpub\wwwroot\http\$MachineName.rdp" -Value ('full address:s:' + $PublicMachineName + ':3389
prompt for credentials:i:1')

if ($bingMapsKey -ne "No") {
    try {
        ('$HardcodeBingMapsKey = "'+$bingMapsKey+'"') | Add-Content "c:\DEMO\BingMaps\HardcodeInput.ps1"
        ('$HardcodeRegionFormat = "default"')         | Add-Content "c:\DEMO\BingMaps\HardcodeInput.ps1"
        . 'c:\DEMO\BingMaps\install.ps1' 4> 'C:\DEMO\BingMaps\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\BingMaps\error.txt" -Value $_.Exception.Message
        Write-Verbose $_.Exception.Message
        $error = $true
    }
}

if ($powerBI -eq "Yes") {
    try {
        . 'c:\DEMO\PowerBI\install.ps1' 4> 'C:\DEMO\PowerBI\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\PowerBI\error.txt" -Value $_.Exception.Message
        Write-Verbose $_.Exception.Message
        $error = $true
    }
}

if ($Office365UserName -ne "No") {
    try {
        ('$HardcodeNavAdminUser = "default"')                                      | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointAdminLoginname = "'+$Office365UserName + '"')         | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointAdminPassword = "'+$Office365Password + '"')          | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointUrl = "default"')                                     | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointSite = "' + ($PublicMachineName.Split('.')[0]) + '"') | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointLanguage = "default"')                                | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointTimezoneId = "default"')                              | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointAppCatalogUrl = "default"')                           | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        ('$HardcodeSharePointMultitenant = "' + $multitenancy + '"')               | Add-Content "c:\DEMO\O365 Integration\HardcodeInput.ps1"
        . 'c:\DEMO\O365 Integration\install.ps1' 4> 'C:\DEMO\O365 Integration\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\O365 Integration\error.txt" -Value $_.Exception.Message
        Write-Verbose $_.Exception.Message
        $error = $true
    }
}

if ($multitenancy -eq "Yes") {

    try {
        . 'c:\DEMO\Multitenancy\install.ps1' 4> 'C:\DEMO\Multitenancy\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\Multitenancy\error.txt" -Value $_.Exception.Message
        Write-Verbose $_.Exception.Message
        $error = $true
    }

} else {

    if ($clickonce -eq "Yes") {
        try {
            . 'c:\DEMO\Clickonce\install.ps1' 4> 'C:\DEMO\Clickonce\install.log'
        } catch {
            Set-Content -Path "c:\DEMO\Clickonce\error.txt" -Value $_.Exception.Message
            Write-Verbose $_.Exception.Message
            $error = $true
        }
    }
}

if ($error) {
    throw "Error installing demo packages"
}
