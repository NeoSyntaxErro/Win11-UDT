# RMM Component Wrapper for Win11DT.ps1 (Windows 11 Deployment Toolkit)
# Scripted by: Steffen Teall 

# Info:
# Due to how Datto RMM Components Execute and the extended execution limitations that will cause a script to fail with a generic error;
# The most steadfast way of ensuring that a componentized actionable lifespan endures the ISO download process is to register the W11LHDT
# script detonation under a scheduled task.  Script logs will output to the temp folder directory where the ISO is downloaded to.  This logging
# does NOT include the actual upgrade process which is stored in C:\install\Windows.log, only the W11LHDT scripts execution, so failed deployments
# can be investigated. 
# ---
# Because this script runs in the SYSTEM users context, a remediation component can be deployed to clean up the endpoint and remove the scheduled
# task as well as the WWin11DT script so it can not be re-used by an end-user.

# Component Variables               # Variable Type                 # Associated Script Variables       # Default Values    # Required
# $env:BypassStorageCheck           Bool {True | False}             $StorageOverride                    $false              No
# $env:ContinueOnRegFail            Bool {True | False}             $RegOverride                        $false              No
# $env:SkipRegistryMod              Bool {True | False}             $SkipBypassRegistryEdits            $false              No
# $env:VerifyISOHash                Bool {True | False}             $VerifyFileHash                     $false              No
# $env:ExpectedHash                 String                          $FileHashValue                      N/A                 No (yes, if VerifyISOHash set to $true)
# $env:Url                          String                          $isoUrl                             N/A                 yes

# NOT Listed in Component Execution input fields: 'remDeploy'.  This value is ALWAYS set to 1 to bypass the banner when script is executed via component.

Copy-Item -Path "Win11UDT.ps1" -Destination "C:\RobTech"

# Validate script presence
$ScriptPath = "C:\RobTech\Win11UDT.ps1"
if (-not (Test-Path $ScriptPath)) {
    Write-Error "`nError: Script path not found: $ScriptPath"
    exit 1
}

# Task Registration Parameters
$TaskName       = "[RT] Win11 Upgrade Deployment Toolkit UPGRADE Task"
$RunTime        = (Get-Date).AddMinutes(5)
$TaskDescription = "Executes the Win11 Deployment Toolk Upgrade Script."
$LogPath        = "C:\RobTech\Win11UpgradeTask.log"

# Address the ExpectedHash Value string issue when building argument array.
if ([string]::IsNullOrWhiteSpace($env:ExpectedHash)) {
    $ExpectedHash = "N/A"       # Only because SOMETHING needs to be passed, if VerifyFileHash is false.
} else {
    $ExpectedHash = $env:ExpectedHash
}

# Build arguments array for safe quoting
$ScriptArgsArray = @(
    '-ExecutionPolicy', 'Bypass',
    '-File', "`"$ScriptPath`"",
    '-StorageOverride', $env:BypassStorageCheck,
    '-RegOverride', $env:ContinueOnRegFail,
    '-SkipBypassRegistryEdits', $env:SkipRegistryMod,
    '-VerifyFileHash', $env:VerifyISOHash,
    '-FileHashValue', "$ExpectedHash",
    '-isoUrl', "$env:Url",
    '-remDeploy', 1
)

# Build action: run PowerShell with output logging
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument (($ScriptArgsArray -join ' '))

# Build trigger: one-time trigger, 5 minutes from now
$Trigger = New-ScheduledTaskTrigger -Once -At $RunTime

# Set task principal to run as SYSTEM
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Write-Output "===============================================================================================`n"
Register-ScheduledTask -TaskName $TaskName `
                       -Action $Action `
                       -Trigger $Trigger `
                       -Principal $Principal `
                       -Description $TaskDescription `
                       -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
                                                              -DontStopIfGoingOnBatteries `
                                                              -StartWhenAvailable:$false `
                                                              -DontStopOnIdleEnd `
                                                              -Hidden:$false)

if ($?) {
    Write-Output "`nAttention: Win 11 Upgrade Task Registered successfully."
    Write-Output "Scheduled to run at: $RunTime"
    Write-Output "`n==============================================================================================="
    Write-Output "Arguments:"
    Write-Output "==============================================================================================="
    Write-Output "StorageOverride: $($env:BypassStorageCheck)"
    Write-Output "RegOverride: $($env:ContinueOnRegFail)"
    Write-Output "SkipBpyassRegistryEdits: $($env:SkipRegistryMod)"
    Write-Output "VerifyFileHash: $($env:VerifyISOHash)"
    Write-Output "ExpectedHash: $ExpectedHash"
    Write-Output "isoUrl: $($env:Url)"
    Write-Output "==============================================================================================="

} else {
    Write-Output "Failed to register scheduled task."
}
exit 0
