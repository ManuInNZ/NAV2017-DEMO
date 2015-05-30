#usage install.ps1

param
(
      [string] $bingMapsKey = $null,
      [string] $clickonce  = $null,
      [string] $powerBI = $null,
      [string] $wordReporting = $null
)

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force
Start-Transcript -Path "C:\DEMO\install.txt"

try {
    if ($bingMapsKey) {
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
