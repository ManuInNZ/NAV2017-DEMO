#usage install.ps1

param
(
      [string] $VMAdminUsername = $null,
      [string] $VMAdminPassword  = $null,
      [string] $PublicMachineName = $null
)

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force
Start-Transcript -Path "C:\DEMO\initialize.txt"

# Other variables
$Language = "W1"
$NavAdminUser = "admin"
$NavAdminPassword = $VMAdminPassword
$CloudServiceName = $PublicMachineName

Copy (Join-Path $PSScriptRoot "Initialize-install.ps1") "C:\DEMO\Initialize\install.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-Certificate.ps1") "C:\DEMO\Initialize\Certificate.ps1"
Copy (Join-Path $PSScriptRoot "Initialize-HelperFunctions.ps1") "C:\DEMO\Initialize\HelperFunctions.ps1"

# Initialize Virtual Machine
('$HardcodeLanguage = "'+$Language+'"')                    | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
('$HardcodeNavAdminUser = "'+$NAVAdminUser+'"')            | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
('$HardcodeNavAdminPassword = "'+$NAVAdminPassword+'"')    | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
('$HardcodeCloudServiceName = "'+$CloudServiceName+'"')    | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
('$HardcodePublicMachineName = "'+$PublicMachineName+'"')  | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"
('$HardcodecertificatePfxFile = "default"')                | Add-Content "c:\DEMO\Initialize\HardcodeInput.ps1"


try {
    . 'c:\DEMO\Initialize\install.ps1' 4> 'C:\demo\Initialize\install.log'
} catch {
    Set-Content -Path "c:\DEMO\error.txt" -Value $_.Exception.Message
}

## Run as admin
#"try {" | Set-Content "c:\DEMO\initialize.ps1"
#". 'c:\DEMO\Initialize\install.ps1' 4> 'C:\demo\Initialize\install.log'" | Add-Content "c:\DEMO\initialize.ps1"
#'} catch {' | Add-Content "c:\DEMO\initialize.ps1"
#'Set-Content -Path "c:\DEMO\error.txt" -Value $_.Exception.Message' | Add-Content "c:\DEMO\initialize.ps1"
#'exit 1' | Add-Content "c:\DEMO\initialize.ps1"
#'}' | Add-Content "c:\DEMO\initialize.ps1"
#
#('$VMAdminUsername = "'+$VMAdminUserName+'"') | Add-Content "c:\DEMO\RunInitialize.ps1"
#('$VMAdminPassword = "'+$VMAdminPassword+'"') | Add-Content "c:\DEMO\RunInitialize.ps1"
#'
#Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force
#Start-Transcript -Path "C:\DEMO\RunInitialize.txt"
#
#function Wait-TaskRunning {
#    param ($TaskName)
#    do {
#        Start-Sleep -Seconds 60
#        $task = Get-ScheduledTask -TaskName $TaskName
#        if ($task.State -ne "Running") {
#            $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
#            if ($taskInfo.LastTaskResult -eq 0) {
#                return "Done"
#            } else {
#                $err = get-content -Path "c:\demo\error.txt" -ErrorAction Ignore
#                return "Error " + $status + " (Error Message: $err)"
#            }
#        } else {
#            return "Running"
#        }
#    } while ($status.Equals("Running"))
#    return $Status
#}
#
#$installationTask = "<?xml version=""1.0"" encoding=""UTF-16""?>
#<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">
#  <RegistrationInfo>
#    <Date>2014-10-18T07:25:03.1892087</Date>
#    <Author>vmadmin</Author>
#  </RegistrationInfo>
#  <Principals>
#    <Principal id=""Author"">
#      <UserId>S-1-5-18</UserId>
#      <RunLevel>HighestAvailable</RunLevel>
#    </Principal>
#  </Principals>
#  <Settings>
#    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
#    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
#    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
#    <AllowHardTerminate>true</AllowHardTerminate>
#    <StartWhenAvailable>false</StartWhenAvailable>
#    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
#    <IdleSettings>
#      <StopOnIdleEnd>true</StopOnIdleEnd>
#      <RestartOnIdle>false</RestartOnIdle>
#    </IdleSettings>
#    <AllowStartOnDemand>true</AllowStartOnDemand>
#    <Enabled>true</Enabled>
#    <Hidden>false</Hidden>
#    <RunOnlyIfIdle>false</RunOnlyIfIdle>
#    <WakeToRun>false</WakeToRun>
#    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
#    <Priority>7</Priority>
#  </Settings>
#  <Actions Context=""Author"">
#    <Exec>
#      <Command>powershell.exe</Command>
#      <Arguments>c:\DEMO\initialize.ps1</Arguments>
#    </Exec>
#  </Actions>
#</Task>"
#
#$retries = 15
#while ($retries -gt 0) {
#    try {
#        Register-ScheduledTask -Xml $installationTask -TaskName "Initialize Virtual Machine" -User "$env:COMPUTERNAME\$VMAdminUserName" -Password $VMAdminPassword –Force -ErrorAction Stop
#        $retries = 0
#    } catch {
#        Start-Sleep -seconds 60
#        $retries--
#    }
#}
#Start-ScheduledTask -TaskName "Initialize Virtual Machine"
#Wait-TaskRunning -TaskName "Initialize Virtual Machine"' | Add-Content "c:\DEMO\RunInitialize.ps1"
#
#
#
#$taskstart = (Get-Date).AddMinutes(1).ToString("s")
#$installationTask = "<?xml version=""1.0"" encoding=""UTF-16""?>
#<Task version=""1.2"" xmlns=""http://schemas.microsoft.com/windows/2004/02/mit/task"">
#  <RegistrationInfo>
#    <Date>2014-10-18T07:25:03.1892087</Date>
#    <Author>vmadmin</Author>
#  </RegistrationInfo>
#  <Triggers>
#    <TimeTrigger>
#      <StartBoundary>$taskstart</StartBoundary>
#      <Enabled>true</Enabled>
#    </TimeTrigger>
#  </Triggers>
#  <Principals>
#    <Principal id=""Author"">
#      <UserId>S-1-5-18</UserId>
#      <RunLevel>HighestAvailable</RunLevel>
#    </Principal>
#  </Principals>
#  <Settings>
#    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
#    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
#    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
#    <AllowHardTerminate>true</AllowHardTerminate>
#    <StartWhenAvailable>false</StartWhenAvailable>
#    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
#    <IdleSettings>
#      <StopOnIdleEnd>true</StopOnIdleEnd>
#      <RestartOnIdle>false</RestartOnIdle>
#    </IdleSettings>
#    <AllowStartOnDemand>false</AllowStartOnDemand>
#    <Enabled>true</Enabled>
#    <Hidden>false</Hidden>
#    <RunOnlyIfIdle>false</RunOnlyIfIdle>
#    <WakeToRun>false</WakeToRun>
#    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
#    <Priority>7</Priority>
#  </Settings>
#  <Actions Context=""Author"">
#    <Exec>
#      <Command>powershell.exe</Command>
#      <Arguments>c:\DEMO\RunInitialize.ps1</Arguments>
#    </Exec>
#  </Actions>
#</Task>"
#
#Register-ScheduledTask -Xml $installationTask -TaskName "Run Virtual Machine Initialization" 
