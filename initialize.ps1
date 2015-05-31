#usage initialize.ps1

param
(
       [string]$VMAdminUsername = $null
      ,[string]$VMAdminPassword  = $null
      ,[string]$Country = $null
      ,[string]$PublicMachineName = $null
      ,[string]$bingMapsKey = $null
      ,[string]$clickonce = $null
      ,[string]$powerBI = $null
      ,[string]$wordReporting = $null
)

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force
Start-Transcript -Path "C:\DEMO\initialize.txt"

# Other variables
$NavAdminUser = "admin"
$NavAdminPassword = $VMAdminPassword
$CloudServiceName = $PublicMachineName

Copy (Join-Path $PSScriptRoot "Initialize-install.ps1")           "C:\DEMO\Initialize\install.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-Certificate.ps1")       "C:\DEMO\Initialize\Certificate.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-HelperFunctions.ps1")   "C:\DEMO\Initialize\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "BingMaps-install.ps1")             "C:\DEMO\BingMaps\install.ps1"
Copy (Join-Path $PSScriptRoot "Clickonce-install.ps1")            "C:\DEMO\Clickonce\install.ps1"
Copy (Join-Path $PSScriptRoot "Multitenancy-install.ps1")         "C:\DEMO\Multitenancy\install.ps1"
Copy (Join-Path $PSScriptRoot "Multitenancy-HelperFunctions.ps1") "C:\DEMO\Multitenancy\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "WarmupNAV-HelperFunctions.ps1")    "C:\DEMO\WarmupNAV\HelperFunctions.ps1"
Copy (Join-Path $PSScriptRoot "O365-install.ps1")                 "C:\DEMO\O365 Integration\install.ps1"
Copy (Join-Path $PSScriptRoot "O365-HelperFunctions.ps1")         "C:\DEMO\O365 Integration\HelperFunctions.ps1"

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
    Set-Content -Path "c:\DEMO\initialize-error.txt" -Value $_.Exception.Message
}

try {
    if ($bingMapsKey -ne "No") {
        ('$HardcodeBingMapsKey = "'+$bingMapsKey+'"') | Add-Content "c:\DEMO\BingMaps\HardcodeInput.ps1"
        . 'c:\DEMO\BingMaps\install.ps1' 4> 'C:\DEMO\BingMaps\install.log'
    }
    if ($clickonce -eq "Yes") {
        . 'c:\DEMO\Clickonce\install.ps1' 4> 'C:\DEMO\Clickonce\install.log'
    }
    if ($powerBI -eq "Yes") {
        . 'c:\DEMO\PowerBI\install.ps1' 4> 'C:\DEMO\PowerBI\install.log'
    }
    if ($wordReporting -eq "Yes") {
        . 'c:\DEMO\Word Reporting\install.ps1' 4> 'C:\DEMO\Word Reporting\install.log'
    }
} catch {
    Set-Content -Path "c:\DEMO\install-error.txt" -Value $_.Exception.Message
}
