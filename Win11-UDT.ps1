<#
.SYNOPSIS
    Windows 11 Upgrade Deployment Toolkit – Automates deployment of Windows 11 from Windows 10 endpoints with optional hardware requirement bypass.

.DESCRIPTION
    Win11UDT.ps1 is a standalone PowerShell-based Windows 11 Deployment Toolkit (W11DT), designed to automate the upgrade of Windows 10 endpoints to Windows 11.
    It supports both compliant and non-compliant hardware scenarios and can be run locally or remotely (e.g., via RMM).
    
    This script offers robust flexibility for enterprise upgrade deployments:
    - Supports hardware check bypass (TPM, RAM, CPU, Secure Boot) via registry tweaks.
    - Downloads and mounts a custom built or official Microsoft sourced ISO for streamlined installation.
    - Can suspend BitLocker, verify ISO integrity, and trigger silent upgrades.
    - Part of a larger toolkit ecosystem, including an RMM wrapper and Ansible Playbook (available via GitHub).

    It is **not** a Windows 11 hardware bypass utility in isolation; it is an automation-first solution for managed and repeatable upgrades across a fleet.

.PARAMETER isoUrl (REQUIRED)
    The URL to the custom Windows 11 ISO (tested with Google Drive, SharePoint, etc.).
    This ISO should have hardware check removals already applied.

.PARAMETER RegOverride (OPTIONAL)
    Forces the registry bypass values to be reapplied even if they exist.
    Primarily used to ensure reliability on Windows 11 24H2 ISO upgrades.

.PARAMETER StorageOverride (OPTIONAL)
    Overrides the available storage space requirement check, allowing installation to proceed on systems with less than the minimum recommended space.

.PARAMETER SkipBypassRegistryEdits (OPTIONAL)
    When set to $true, bypass-related registry edits will be skipped (for compliant systems). Defaults to $true.

.PARAMETER VerifyFileHash (OPTIONAL)
    Enables SHA-256 hash validation on the downloaded ISO for integrity checking.

.PARAMETER FileHashValue (OPTIONAL)
    Required if VerifyFileHash is set to true. The expected SHA-256 hash value of the ISO file.

.PARAMETER remDeploy (OPTIONAL)
    Used to indicate remote deployment scenarios (e.g., via RMM tools). Enables features such as toast notifications for user awareness.

.EXAMPLE
    ./Win11UDT.ps1 -isoUrl "https://your.storage/Win11.iso"
    ./Win11DT.ps1 -isoUrl "https://your.storage/Win11.iso" -StorageOverride $true -RegOverride $true

.NOTES
    Author: Steffen Teall
    Version: 1.0
    Date: 2025-06-19
    Last Updated: 2025-06-19 0420 PST
    License: MIT

    Part of the Windows 11 Deployment Toolkit (Win11DT) GitHub Repository:
    Includes: PowerShell script, RMM component wrapper, and Ansible Playbook.
#>

####   P A R A M E T E R S    ####

# Boolean paramaters have been set to 'object' to allow for flexible input handling.
# This allows for string inputs like "True" or "False" to be converted to boolean values.

param (
    [Parameter(Mandatory = $false)]             
    [object]$StorageOverride,                   # Changed from 'bool' 

    [Parameter(Mandatory = $true)]
    [string]$isoUrl,

    [Parameter(Mandatory = $false)]
    [object]$RegOverride,                       # Changed from 'bool'

    [Parameter(Mandatory = $false)]
    [object]$SkipBypassRegistryEdits,           # Changed from 'bool'  

    [Parameter(Mandatory = $false)]
    [object]$VerifyFileHash,                    # Changed from 'bool'

    [Parameter(Mandatory = $false)]
    [string]$FileHashValue,

    # This Paramater is only applicable when deploying via RMM Component for remote upgrade.
    # but can be enabled if you would like Toast Notifications.
    [Parameter(Mandatory = $false)]
    [int]$remDeploy
)

####    P A R A M E T E R    V A L I D A T I O N    ####
# Converts string inputs to boolean values for StorageOverride, RegOverride, SkipBypassRegistryEdits, and VerifyFileHash.

if ($null -eq $StorageOverride) {
    $StorageOverride = $false    
}
elseif ($StorageOverride -is [string]) {
    $StorageOverride = [bool]::Parse($StorageOverride)
}

# When set to True will continue script actions if a registry modification fails to apply.
if ($null -eq $RegOverride) {   
    $RegOverride = $false
}
elseif ($RegOverride -is [string]) {
    $RegOverride = [bool]::Parse($RegOverride)
}

# When set to True will not attempt to modify registry hardware check values.
# Set to True by default assuming the upgrade is taking place on compatible hardware.
if ($null -eq $SkipBypassRegistryEdits) {
    $SkipBypassRegistryEdits = $true
}
elseif ($SkipBypassRegistryEdits -is [string]) {
    $SkipBypassRegistryEdits = [bool]::Parse($SkipBypassRegistryEdits)
}

# When set to True will require a file hash verification upon successful download of the ISO.
if ($null -eq $VerifyFileHash) {
    $VerifyFileHash = $false
}
elseif ($VerifyFileHash -is [string]) {
    $VerifyFileHash = [bool]::Parse($VerifyFileHash)
}

# If VerifyFileHash being set to True requires an expected file hash value to be supplied when executed.
if (($VerifyFileHash -eq $true) -and ($null -eq $FileHashValue)) {
    Write-Host "[!]::Err::Must provide file hash value if VerifyFileHash is set as True." -ForegroundColor White -BackgroundColor Red
    Start-Sleep 3
    exit 1
}

if ($null -eq $remDeploy) {
    # Default to non Remote Deployment if not otherwise declared.
    $remDeploy = 0
}
elseif ($remDeploy -is [string]) {
    $remDeploy = [int]::Parse($remDeploy)
}

# This is added in case there is an end-user on the endpoint at the time of upgrade.
# Toast Notifications are only enabled when $remDeploy value is set to 1.
####    T O A S T    N O T I F I C A T I O N S    ####

# NOTE: Toast notifications are executed when remDeploy is set to 1.  If this script is running in the SYSTEM user context
#       as which is standard in the RMM Component Deployment method, the toast notification will not show.  Run in the user
#       context to have Toast-Notify pop-ups displayed.  The user needs to have the appropriate administrative permissions to 
#       install the windows update.  Warning: UAC Prompts may prevent successfull successfull detonation.

function Toast-Notify {
    param(
        [Parameter(Mandatory = $true)]
        [String]$msg
    )
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::WinLogo
    $notify.BalloonTipTitle = "Windows 11 Upgrade Notification"
    $notify.BalloonTipText = "$msg"
    $notify.BalloonTipIcon = "Info"
    $notify.Visible = $true
    $notify.ShowBalloonTip(10)  # Shows for 20 seconds
    $notify.Dispose()    
}

####    C H E C K    F O R    /    C R E A T E    T M P    F O L D E R    ####

$logPath = "C:\temp\Win11DT_Log.txt"

if (-not(Test-Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType Directory | Out-Null    
    Write-Output "[*]::Attn::temp folder created."
}

####    L O G G I N G    F U N C T I O N S    ####

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)   
}

function log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$logMsg
    )

    $logPath = "C:\temp\Win11DT_Log.txt"
    $fullMsg = "$(Get-TimeStamp) $logMsg"

    # Write-Output $fullMsg
    $fullMsg | Tee-Object -FilePath $logPath -Append
}


if ($remDeploy -eq 1) {
    Toast-Notify "OS version upgrade has started on this endpoint."
    log "[*]::Attn::Toast Notification sent to user."
} 

# This needs to be set to NOT display when remDeploy mode is activated.
$banner = @'

 .--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--. 
/ .. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \
\ \/\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ \/ /
 \/ /`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'\/ / 
 / /\   ________ _______ _______      ____   ____        _______ _____ _______   / /\ 
/ /\ \ |  |  |  |_     _|    |  |    |_   | |_   |      |   |   |     \_     _| / /\ \
\ \/ / |  |  |  |_|   |_|       |     _|  |_ _|  |_     |   |   |  --  ||   |   \ \/ /
 \/ /  |________|_______|__|____|    |______|______|    |_______|_____/ |___|    \/ / 
 / /\.--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--./ /\ 
/ /\ \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \/\ \
\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `' /
 `--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--' 
  
                          Windows 11 Upgrade Deployment Toolkit
                                     @neosyntaxerro

'@

if ($remDeploy -ne 1) {
    Write-Output $banner
    Start-Sleep 3
} 

####    A V A I L A B L E    S T O R A G E    C H E C K    ####

if (([Math]::Round((Get-PsDrive C).Free / 1GB)) -lt 15) {
    log "[!]::Err::Not enough free space to safely conduct upgrade."
    if ($StorageOverride -eq $true) {
        log "[*]::Attn::Storage override flag set to 'True'."
        log ("[>]::Attn::Free Storage Space: {0} GB" -f [Math]::Round((Get-PSDrive C).Free / 1GB))
    } else {
        log "[!]::Err::Exiting..."
        Start-Sleep 3
        exit 1
    }
} else {
    log "[*]::Attn::Avail storage check passed."
    log ("[>]::Attn::Free Storage Space: {0} GB" -f [Math]::Round((Get-PSDrive C).Free / 1GB))
}

####    D O W N L O A D    C U S T O M    I S O    U R L    ####

log "[*]::Attn::Downloading ISO from supplied URL" 
Invoke-WebRequest -Uri $isoUrl -OutFile "C:\temp\Win11Upgrade.iso"
# Start-BitsTransfer -Source $isoUrl -Destination "C:\temp\Win11Upgrade.iso"
if (-not($?)) {
    log "[!]::Err::Failed to download ISO from URL."
    Start-Sleep 3
    exit 1
} else {
    log "[*]::Attn::ISO download completed." 
    if ($VerifyFileHash -eq $true) {
        $computedHash = (Get-FileHash "C:\temp\Win11Upgrade.iso" -Algorithm Sha256).Hash
        if ($computedHash -ne $FileHashValue) {
            log "[!]::Err::Computed file hash of ISO does not match provided hash.  Aborting..."
            Remove-Item -Force "C:\temp\Win11Upgrade.iso"
            Sleep 3
            exit 1
        } else {
            log "[*]::Attn::File hash verification succeeded." 
        }
    } else {
        log "[*]::Attn::File hash verification skipped." 
    }
}

####    R E G I S T R Y    U P G R A D E    B Y P A S S    K E Y S    ####

if ($SkipBypassRegistryEdits -eq $false) {
    log "[*]::Attn::Starting hardware check bypass registry modifications." 
    if (-not (Test-Path "HKLM:\SYSTEM\Setup\LabConfig")) {
        New-Item -Path "HKLM:\SYSTEM\Setup" -Name "LabConfig" -Force | Out-Null
        if ($?) {
            log "[*]::Attn::Successfully created LabConfig registry item for 'LabConfig'." 
        } else {
            log "[!]::Err::Failed to create LabConfig registry item.  Are you running as Admin?"
        }
    } else {
        log "[*]::Attn::LabConfig Registry item already exists. Do nothing." 
    }

    $regCommands = @(
    'reg add HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig\ /v BypassTPMCheck /t REG_DWORD /d 1 /f',
    'reg add HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig\ /v BypassRAMCheck /t REG_DWORD /d 1 /f',
    'reg add HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig\ /v BypassSecureBootCheck /t REG_DWORD /d 1 /f',
    'reg add HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig\ /v BypassCPUCheck /t REG_DWORD /d 1 /f',
    'reg add HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup\ /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f'
    )

    foreach ($cmd in $regCommands) {
        $result = cmd /c $cmd
        if ($LASTEXITCODE -eq 0) {
            $valueName = $cmd.Split(' ')[4]
            log "[*]::Attn::Successfully set reg key: $valueName" 
        } else {
            log "[!]::Err::Failed to set: $cmd"
            if ($RegOverride -eq $true) {
                log "[*]::Attn::Registry override set to True.  Continuing..."
            } else {
                log "[!]::Err::Registry override not declared or set to false. Exiting..."
                Start-Sleep 3
                exit 1
            }
        }
    }
} else {
    log "[*]::Attn::Skipping registry modifications to bypass hardware checks."
}

####    T E M P O R A R I L Y    S U S P E N D    B I T L O C K E R    E N C    ####

log "[*]::Attn:Suspending BitLocker on all encrypted drives for the next 3 reboots."
Get-BitLockerVolume | Where-Object {$_.ProtectionStatus -eq "On"} | ForEach-Object {
    log "[*]::Attn::Suspending BitLocker on drive $($_.MountPoint)"
    Suspend-BitLocker -MountPoint $_.MountPoint -RebootCount 5
}

####    M O U N T    T H E    I S O    ####

log "[*]::Attn::Mounting ISO to host."
$diskImage = Mount-DiskImage -ImagePath "C:\temp\Win11Upgrade.iso"
if (-not($?)) {
    log "[!]::Err::Failed to mount ISO. Exiting..."
    Start-Sleep 3
    exit 1
} else {
    $devicePath = ($diskImage | Get-DiskImage).DevicePath
    $driveLetter = (Get-DiskImage -DevicePath $devicePath | Get-Volume).DriveLetter + ":\"
    log "[*]::Attn::ISO mounted to volume: $driveLetter"
}

####    L A U N C H    U P G R A D E    A P P L I C A T I O N    ####

log "[*]::Attn::Changing Directories to mount point / Executing Upgrade."
Set-Location $driveLetter
# Consider adding paramater to make the command execution modifiable. { upgrade | clean }
./setup.exe /auto upgrade /migratedrivers all /resizerecoverypartition enable /dynamicupdate disable /eula accept /quiet /uninstall disable /compat ignorewarning /copylogs C:\Install\WinSetup.log
if ($?) {
    if ($remDeploy -eq 1) {
        Toast-Notify "OS Version Upgrade is modifying critical system files and will reboot without further notification. ETA: 1 Hour."
        log "[*]::Attn::Toast Notification sent to user."
        # Attempt to remove the scheduled task that was created by RMM Component.
        $TaskName = "Win11 Upgrade via Win11-UDT"
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirme:$false
            log "[*]::Attn::Successfully removed scheduled task."
        }
        catch {
            log "[!]::Err::Failed to remove scheduled task.  It may have already been removed or does not exist."
        }
    }
    log "[*]::Attn::Upgrade process successfully launched. Exiting..."
    Start-Sleep 3
    exit 0
} else {
    log "[!]::Err::Upgrade process failed to launch. Exiting..."
    Start-Sleep 3
    exit 1
}
