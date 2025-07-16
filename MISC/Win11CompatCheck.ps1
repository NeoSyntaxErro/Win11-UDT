# Windows 11 Upgrade Compatability Check
# Scripted By: Steffen Teall

# Minimum Windows 11 Upgrade Requirements:
# 1. Processor: 1Ghz or faster CPU with 2 or more physical cores.
# 2. RAM      : 4 GB or more.
# 3. Storage  : 64 GB of available storage. Disk Size not currently available.
# 4. Firmware : UEFI / Secure Boot Capable.
# 5. TPM      : Trusted Platform Module version 2.0.
# 6. OS Build : Minimum 19041

# Run this script directly with: 
# Set-ExecutionPolicy Bypass -Scope CurrentUser -Force; iex (irm 'https://raw.githubusercontent.com/neosyntaxerro/Win11-UDT/main/Win11CompatCheck.ps1')
#
# Actual URL Ref: https://github.com/NeoSyntaxErro/Win11-UDT/blob/main/MISC/Win11CompatCheck.ps1

param (
  [Parameter(Mandatory = $false)]
  [object]$AutoUpdate
)

# Set Default value if not provided, convert to string if object input provided (RMM)
if ($null -eq $AutoUpgrade) {
  $AutoUpdate = $false
}
elseif ($AutoUpdate -is [string]) {
  $AutoUpdate = [bool]::Parse($AutoUpdate)
}

$banner = @'
              ,---------------------------,
              |  /---------------------\  |
              | |                       | |
              | |        Win 11         | |
              | |     Compat Check      | |
              | |                       | |
              | |      *beep boop       | |
              |  \_____________________/  |
              |___________________________|
            ,---\_____     []     _______/------,
          /         /______________\           /|
        /___________________________________ /  | ___
        |                                   |   |    )
        |  _ _ _                 [-------]  |   |   (
        |  o o o                 [-------]  |  /    _)_
        |__________________________________ |/     /  /
    /-------------------------------------/|      ( )/
  /-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/ /
/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/-/ /
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'@

Write-Output $banner

# 1.
####    C P U    C O M P A T    C H E C K    ####

$cpuCheck       = Get-WmiObject Win32_Processor | Where-Object { $_.NumberOfCores -ge 2 }
$coreCount      = [int]$cpuCheck.NumberOfCores
$processorSpeed = [math]::Round($cpuCheck.MaxClockSpeed / 1000, 1) 

Write-Host "`n`nCPU COMPATABILITY CHECK" -ForegroundColor Cyan 
Write-Output "==========================================================="
Write-Output "CPU Core Count     : $([string]$coreCount) Physical Cores"
Write-Output "CPU Processor Speed: $([string]$processorSpeed) GHZ"
Write-Output "==========================================================="
if (($coreCount -ge 2) -and ([int]$processorSpeed -ge 1.0)) {
    Write-Host "`CPU Check Result: PASSED" -ForegroundColor Black -BackgroundColor Green
} else {
    Write-Host "CPU Check Result: FAILED" -ForegroundColor White -BackgroundColor Red
}
Write-Output "===========================================================`n"

#2.
####    R A M    R E S O U R C E    C H E C K    ####

Write-Host "RAM COMPATABILITY CHECK" -ForegroundColor Cyan
Write-Output "==========================================================="
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
Write-Output "Total RAM: $ramGB GB"
Write-Output "==========================================================="
if ($ramGB -ge 4) {
    Write-Host "RAM Resource Check Result: PASSED" -ForegroundColor Black -BackgroundColor Green
} else {
    Write-Host "RAM Resource Check Result: FAILED" -ForegroundColor White -BackgroundColor Red
}
Write-Output "===========================================================`n"

# 3.
####    A V A I L A B L E    S T O R A G E    C H E C K    ####

# 4.
####    T P M    2 . 0    C H E C K    ####

try { 
    $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
    Write-Host "TPM 2.0 COMPATABILITY CHECK" -ForegroundColor Cyan
    Write-Output "==========================================================="
    if ([int]$tpm.SpecVersion.split(',')[0] -eq 2.0) {
        Write-Host "TPM 2.0 Result: PASSED" -ForegroundColor Black -BackgroundColor Green
    } else {
        Write-Host "TPM 2.0 Check Result: FAILED" -ForegroundColor White -BackgroundColor Red
    }
} catch {
    Write-Host "ERROR Grabbing TPM Compatability.  TPM UNVERIFIED." -ForegroundColor White -BackgroundColor Red
}
Write-Output "===========================================================`n"

# 5. 
####    S E C U R E    B O O T    C H E C K    ####

Write-Host "SECURE BOOT ENABLED / COMPATIBLE CHECK" -ForegroundColor Cyan
Write-Output "==========================================================="
$secureBoot = Confirm-SecureBootUEFI
if ($secureBoot) {
    Write-Host "Secure Boot Check Result: PASSED" -ForegroundColor Black -BackgroundColor Green
} else {
    Write-Host "Secure Boot Check Result: FAILED" -ForegroundColor White -BackgroundColor Red
}
Write-Output "===========================================================`n"

# 6. 
####    U E F I    C H E C K    ####

Write-Host "UEFI CHECK" -ForegroundColor Cyan
Write-Output "==========================================================="
$bcdOut = bcdedit | Out-String
if ($bcdOut -match "path.*EFI") {
    Write-Host "UEFI Check Results: PASSED [UEFI]." -ForegroundColor Black -BackgroundColor Green
} else {
    Write-Host "UEFI Check Results: FAILED [BIOS]." -ForegroundColor White -BackgroundColor Red
}
Write-Output "===========================================================`n"

# 7.
####    O S    B U I L D    V E R I F I C A T I O N    ####

$osBuild  = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Host "OS BUILD VERIFICATION" -ForegroundColor Cyan
Write-Output "==========================================================="
if ([int]$osBuild -ge 19041) {
    Write-Host "OS BUILD CHECK: PASSED" -ForegroundColor Black -BackgroundColor Green
    Write-Output "===========================================================`n"
    Write-Output "Finished!"
    pause
    exit 0
} else {
    Write-Host "OS BUILD CHECK: FAILED" -ForegroundColor White -BackgroundColor Red 
    Write-Output "==========================================================="
    Write-Output "           ATTEMPTING WINDOWS 10 FEATURE UPDATE            "
    Write-Output "==========================================================="
    
    if (-not(Test-Path "C:\temp")) {
        New-Item -ItemPath "C:\temp" -ItemType Directory
    }
    
    Write-Output "Downloading: Windows 11 Update Assistant..."
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkID=799445" -OutFile "C:\temp\Windows10Update.exe"
    if ($?) {
        # Quiet Update Installation, with a 30 second warning prior to reboot.
        Write-Output "Windows 10 Update Assistant Download Completed."
        Start-Process -FilePath "C:\temp\Windows10Update.exe" -ArgumentList "/quietinstall /skipeula /auto upgrade /warnrestart[:30]"    # Do I add logging with '-RedirectStandardOutput "C:\temp\Win10Update.log"
        if ($?) {
            Write-Host "Windows 10 Update Assistant Successfully Launched." -ForegroundColor Black -BackgroundColor Green
            Write-Output "Workstation will reboot 30 seconds after updates have finished."
            Start-Sleep 3
            exit 0
        } else {
            Write-Host "FAILED to launch Windows 10 Update Assistant." -ForegroundColor White -BackgroundColor Red
            Write-Output "==========================================================="
            Start-Sleep 3
            exit 1
        }
    } else {
        Write-Host "FAILED to download Windows 10 Update Assistant." -ForegroundColor White -BackgroundColor Red
        Write-Output "==========================================================="
        Start-Sleep 3
        exit 1
    }
}
