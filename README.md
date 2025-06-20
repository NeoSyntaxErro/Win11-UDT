# Windows 11 Upgrade Deployment Toolkit 

Automated PowerShell-based deployment solution for upgrading Windows 10 systems to Windows 11 — with optional hardware check bypass for unsupported devices.  Hardware bpyass enabling requires a custom Windows 11 23H2 iso file.
Some 24H2+ iso images will accept bypasses if the harware checks failures are within a certain tolerance threshold; Otherwise, a 23H2 iso is recommended.

Please see: https://github.com/AveYo/MediaCreationTool.bat for creating a Windows 11 iso with hardware / checks & Bypasses integrated into the setup.exe upgrade utility. 

---

## 📌 Overview

`Win11-UDT.ps1` is a comprehensive and customizable PowerShell script built to streamline in-place upgrades from Windows 10 to Windows 11 across managed endpoints. Designed with IT admins, MSPs, and deployment engineers in mind, it supports both compliant and non-compliant hardware configurations and can be executed locally or remotely (e.g., via RMM or automation platforms).

This script is **not** a standalone hardware bypass tool — it is an **automation-first** upgrade solution with support for ISO validation, BitLocker handling, and upgrade logging.

---

## ✨ Features

- ✅ Automates upgrade to Windows 11 using a specified ISO
- ✅ Supports registry-based hardware requirement check bypasses (TPM, Secure Boot, RAM, CPU)
- ✅ Verifies ISO SHA-256 hash (optional)
- ✅ Automatically suspends BitLocker to avoid upgrade issues
- ✅ Toast notifications for user awareness (when deployed remotely)
- ✅ Gracefully handles insufficient storage conditions
- ✅ Part of a modular toolkit that includes an RMM wrapper and Ansible playbook

---

## 📥 Parameters

| Name                   | Required | Type   | Description |
|------------------------|----------|--------|-------------|
| `-isoUrl`              | ✅        | String | HTTPS URL to your Windows 11 ISO (must already have hardware checks removed if used for bypass). |
| `-StorageOverride`     | ❌        | Bool   | Overrides storage check (use if disk space is low but intentional). |
| `-RegOverride`         | ❌        | Bool   | Forces registry keys to be set again even if they already exist. |
| `-SkipBypassRegistryEdits` | ❌    | Bool   | Skips applying bypass keys (for compliant devices). Defaults to `$true`. |
| `-VerifyFileHash`      | ❌        | Bool   | Enables verification of the ISO via SHA-256 hash. |
| `-FileHashValue`       | ❌        | String | The expected SHA-256 hash of the ISO (required if `VerifyFileHash` is true). |
| `-remDeploy`           | ❌        | Int    | Enable toast notifications (used for remote deployments like RMM). Set to `1` to enable. |

---

## 🧪 Examples

```powershell
# Basic upgrade using ISO from secure storage
.\Win11UDT.ps1 -isoUrl "https://sharepoint.com/path/Win11.iso"

# Upgrade with storage override and bypass registry enforcement
.\Win11UDT.ps1 -isoUrl "https://myhostedstorage.com/Win11.iso" -StorageOverride $true -RegOverride $true

# With ISO hash verification
.\Win11UDT.ps1 -isoUrl "https://cdn.server.com/win11.iso" -VerifyFileHash $true -FileHashValue "ABCDEF1234567890..." -remDeploy 1
```

---

## 🚦 Behavior Notes

- 💾 **Disk Space Check**: Script requires ≥15GB free unless `-StorageOverride` is used.
- 🔐 **BitLocker Handling**: Script suspends BitLocker on protected volumes for 5 reboots.
- 🔧 **Registry Tweaks**: Uses `LabConfig` keys to bypass upgrade hardware checks if needed.
- 📦 **ISO Mounting**: The ISO is downloaded to `C:	emp\Win11Upgrade.iso` and mounted before execution.
- 🧠 **Silent Upgrade**: Executes `setup.exe` with `eula accept`, `quiet`, and `compat ignorewarning` flags.
- 🔔 **User Notifications**: Toast notifications appear when `-remDeploy 1` is set.  remDeploy is enabled by default during RMM component deployments.

---

## 📁 Log Output

Logs are written to:

```plaintext
C:\\temp\Win11DT_Log.txt
```

This includes every major step: disk check, registry modification, ISO verification, BitLocker status, and setup result.

---

## 🛡️ Requirements

- PowerShell 5.1+
- Admin privileges
- Internet access to download ISO
- Custom or Microsoft ISO with bypass support (if applicable)

---

## ⚙️ Toolkit Ecosystem

This script is part of the broader **Windows 11 Deployment Toolkit**, which includes:

- 🔹 `Win11UDT.ps1` – This standalone upgrade tool.
- 🔹 RMM wrapper script for executing remotely via systems like Datto.
- 🔹 Ansible Playbook for bulk Linux-based provisioning and execution.
- 🔹 PowerShell HTTP Server utility for hosting images locally on your network.

---

## 👤 Author

**Steffen Teall**  
`@neosyntaxerro`  
MIT License | Version 1.0 | June 10, 2025

---

## 🧾 Disclaimer

This script is intended for educational and professional deployment use. While it includes registry modifications for bypassing hardware restrictions, the responsibility of using such methods lies with the operator.

Always test in a lab before deploying to production environments.

---
