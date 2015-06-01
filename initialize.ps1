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
      ,[string]$wordReporting = $null
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
Add-Content -Path (Join-Path $PSScriptRoot "parameters.ps1") -Value ('$wordReporting     = ''' + $wordReporting + '''')

# Other variables
$NavAdminUser = "admin"
$NavAdminPassword = $VMAdminPassword
$CloudServiceName = $PublicMachineName
$MachineName = [Environment]::MachineName

Copy (Join-Path $PSScriptRoot "Initialize-install.ps1")               "C:\DEMO\Initialize\install.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-Default.aspx")              "C:\DEMO\Initialize\Default.aspx"
Copy (Join-Path $PSScriptRoot "Initialize-web.config")                "C:\DEMO\Initialize\web.config"
Copy (Join-Path $PSScriptRoot "Initialize-Certificate.ps1")           "C:\DEMO\Initialize\Certificate.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-HelperFunctions.ps1")       "C:\DEMO\Initialize\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "BingMaps-install.ps1")                 "C:\DEMO\BingMaps\install.ps1"
Copy (Join-Path $PSScriptRoot "Clickonce-install.ps1")                "C:\DEMO\Clickonce\install.ps1"
Copy (Join-Path $PSScriptRoot "PowerBI-install.ps1")                  "C:\DEMO\PowerBI\install.ps1"
Copy (Join-Path $PSScriptRoot "Word Reporting-install.ps1")           "C:\DEMO\Word Reporting\install.ps1"
Copy (Join-Path $PSScriptRoot "Multitenancy-install.ps1")             "C:\DEMO\Multitenancy\install.ps1"
Copy (Join-Path $PSScriptRoot "Multitenancy-HelperFunctions.ps1")     "C:\DEMO\Multitenancy\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "Multitenancy-MTDemoAdminShell.psm1")   "C:\DEMO\Multitenancy\MTDemoAdminShell.ps1"
Copy (Join-Path $PSScriptRoot "WarmupNAV-HelperFunctions.ps1")        "C:\DEMO\WarmupNAV\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "O365 Integration-install.ps1")         "C:\DEMO\O365 Integration\install.ps1"
Copy (Join-Path $PSScriptRoot "O365 Integration-HelperFunctions.ps1") "C:\DEMO\O365 Integration\HelperFunctions.ps1"

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
    throw
}

Set-Content -Path "c:\inetpub\wwwroot\http\$MachineName.rdp" -Value ('full address:s:' + $PublicMachineName + ':3389
prompt for credentials:i:1')

if ($bingMapsKey -ne "No") {
    try {
        ('$HardcodeBingMapsKey = "'+$bingMapsKey+'"') | Add-Content "c:\DEMO\BingMaps\HardcodeInput.ps1"
        . 'c:\DEMO\BingMaps\install.ps1' 4> 'C:\DEMO\BingMaps\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\BingMaps\error.txt" -Value $_.Exception.Message
    }
}

if ($powerBI -eq "Yes") {
    try {
        . 'c:\DEMO\PowerBI\install.ps1' 4> 'C:\DEMO\PowerBI\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\PowerBI\error.txt" -Value $_.Exception.Message
    }
}

if ($wordReporting -eq "Yes") {
    try {
        . 'c:\DEMO\Word Reporting\install.ps1' 4> 'C:\DEMO\Word Reporting\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\Word Reporting\error.txt" -Value $_.Exception.Message
    }
}

if ($multitenancy -eq "Yes") {

    try {
        . 'c:\DEMO\Multitenancy\install.ps1' 4> 'C:\DEMO\Multitenancy\install.log'
    } catch {
        Set-Content -Path "c:\DEMO\Multitenancy\error.txt" -Value $_.Exception.Message
    }

} else {

    if ($clickonce -eq "Yes") {
        try {
            . 'c:\DEMO\Clickonce\install.ps1' 4> 'C:\DEMO\Clickonce\install.log'
        } catch {
            Set-Content -Path "c:\DEMO\Clickonce\error.txt" -Value $_.Exception.Message
        }
    }

}
