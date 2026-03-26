# Invoke-Storage

A PowerShell module that automates the full lifecycle of Windows Server Storage Spaces
resources — pool, virtual disk, volume, and workload-specific artifacts — in a single
command.

Built with the [Sampler](https://github.com/gaelcolas/Sampler) framework, following
production-grade standards: ShouldProcess safety, structured logging, cross-platform
unit testing, and 85%+ code coverage.

---

## Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
- [Workload Profiles](#workload-profiles)
- [Usage Examples](#usage-examples)
- [Architecture](#architecture)
- [Logging Framework](#logging-framework)
- [Building and Testing](#building-and-testing)
- [CI/CD](#cicd)
- [License](#license)

---

## Overview

`Invoke-Storage` provisions a complete Windows Server Storage Spaces stack optimised
for enterprise workloads (Active Directory, SQL Server, SCCM, WSUS). One call creates:

1. A storage pool from poolable physical disks
2. A virtual disk (simple, mirror, or parity resiliency; fixed or thin provisioning)
3. A GPT-partitioned volume with an assigned drive letter
4. An NTFS volume label
5. Workload-specific directories and marker files (e.g. `no_sms_on_drive.sms`)

The same `-Remove` switch tears everything down in reverse order. All destructive
operations require confirmation (`ConfirmImpact = High`) unless `-Force` is passed.

---

## Requirements

| Requirement | Minimum version |
|---|---|
| PowerShell | 7.0 |
| Operating System | Windows Server (ProductType 3) |
| Privileges | Local Administrator |
| Windows Storage module | Included with Windows Server |

---

## Installation

### From PSGallery

```powershell
Install-Module -Name Invoke-Storage
```

### From Source

```powershell
git clone <repo-url>
cd STORAGE
./build.ps1 -ResolveDependency -tasks build
Import-Module ./output/module/Invoke-Storage/<version>/Invoke-Storage.psd1
```

---

## Quick Start

```powershell
# Create a 100 GB NTDS volume on drive D:
Invoke-Storage -StoragePoolName 'ADPool' `
               -VirtualHardDiskName 'NTDS_VDisk' `
               -Workload NTDS `
               -SizeInGB 100

# Remove the same volume
Invoke-Storage -StoragePoolName 'ADPool' `
               -VirtualHardDiskName 'NTDS_VDisk' `
               -Workload NTDS `
               -Remove
```

---

## Command Reference

### `Invoke-Storage`

Public entry point. Runs preflight checks, then delegates to `New-Storage`.

```
Invoke-Storage
    -StoragePoolName    <string>   # Friendly name for the storage pool
    -VirtualHardDiskName <string>  # Friendly name for the virtual disk
    -Workload           <string>   # Workload profile (see table below)
    [-FileSystemLabel   <string>]  # NTFS label override (defaults to workload name)
    [-ResiliencySettingName <Simple|Mirror|Parity>]  # Default: Simple
    [-ProvisioningType  <Fixed|Thin>]                # Default: Thin
    [-SizeInGB          <int64>]   # Disk size in GB (required unless -UseMaximumSize)
    [-UseMaximumSize]              # Use all available pool space
    [-Remove]                      # Remove resources instead of creating
    [-NoPostCreateArtifacts]       # Skip workload directories and marker files
    [-PassThru]                    # Return rich object instead of drive letter
    [-Force]                       # Suppress all confirmation prompts
    [-WhatIf]                      # Preview without making changes
    [-Confirm]                     # Explicit confirmation prompt
```

**Outputs:**

| Mode | Return value |
|---|---|
| Default (create) | `[char]` — drive letter, e.g. `'D'` |
| `-PassThru` | `PSCustomObject` with `DriveLetter`, `StoragePool`, `VirtualDisk`, `Volume`, `Capacity` |
| `-Remove` | Nothing (`void`) |

---

## Workload Profiles

Each workload profile determines what is created after the volume is formatted.

| Workload | Post-create artifacts |
|---|---|
| `SYSVOL` | `<drive>:\SYSVOL\` (hidden) |
| `NTDS` | `<drive>:\NTDS\` (hidden), `<drive>:\NTDS\LOGS\` (hidden) |
| `ConfigMgrInstall` | `C:\no_sms_on_drive.sms` |
| `ApplicationSources` | `<drive>:\no_sms_on_drive.sms` |
| `ContentLibrary` | `<drive>:\no_sms_on_drive.sms` |
| `SQL_MDF` | `<drive>:\DataBase\`, `<drive>:\no_sms_on_drive.sms` |
| `SQL_LDF` | `<drive>:\DataBase\`, `<drive>:\no_sms_on_drive.sms` |
| `TempDB` | `<drive>:\DataBase\`, `<drive>:\no_sms_on_drive.sms` |
| `WSUSDB` | `<drive>:\DataBase\`, `<drive>:\no_sms_on_drive.sms` |
| `Generic` | None — raw volume only |

`no_sms_on_drive.sms` markers prevent SCCM from using the drive as a content source.

---

## Usage Examples

### Active Directory Domain Services

```powershell
# NTDS database volume — 100 GB, simple resiliency
Invoke-Storage -StoragePoolName 'ADPool' `
               -VirtualHardDiskName 'NTDS_VDisk' `
               -Workload NTDS `
               -SizeInGB 100 `
               -Confirm:$false

# SYSVOL volume — use all available space, mirror resiliency
Invoke-Storage -StoragePoolName 'ADPool' `
               -VirtualHardDiskName 'SYSVOL_VDisk' `
               -Workload SYSVOL `
               -ResiliencySettingName Mirror `
               -UseMaximumSize `
               -Confirm:$false
```

### SQL Server

```powershell
# SQL MDF volume — 500 GB, thin provisioning
Invoke-Storage -StoragePoolName 'SQLPool' `
               -VirtualHardDiskName 'SQL_MDF_VDisk' `
               -Workload SQL_MDF `
               -SizeInGB 500

# SQL LDF (log) volume — 200 GB with a custom label
Invoke-Storage -StoragePoolName 'SQLPool' `
               -VirtualHardDiskName 'SQL_LDF_VDisk' `
               -Workload SQL_LDF `
               -SizeInGB 200 `
               -FileSystemLabel 'SQL_LOGS'

# TempDB volume — fixed provisioning for predictable performance
Invoke-Storage -StoragePoolName 'SQLPool' `
               -VirtualHardDiskName 'TempDB_VDisk' `
               -Workload TempDB `
               -SizeInGB 100 `
               -ProvisioningType Fixed
```

### Configuration Manager

```powershell
# ConfigMgr install volume
Invoke-Storage -StoragePoolName 'CMPool' `
               -VirtualHardDiskName 'CM_Install_VDisk' `
               -Workload ConfigMgrInstall `
               -SizeInGB 150

# Content Library volume — parity for read-heavy workloads
Invoke-Storage -StoragePoolName 'CMPool' `
               -VirtualHardDiskName 'CM_Content_VDisk' `
               -Workload ContentLibrary `
               -ResiliencySettingName Parity `
               -UseMaximumSize
```

### Preview and Automation

```powershell
# WhatIf — see what would happen without making changes
Invoke-Storage -StoragePoolName 'TestPool' `
               -VirtualHardDiskName 'Test_VDisk' `
               -Workload Generic `
               -SizeInGB 50 `
               -WhatIf

# Force — suppress all confirmation prompts (CI/CD, DSC)
Invoke-Storage -StoragePoolName 'AutoPool' `
               -VirtualHardDiskName 'Auto_VDisk' `
               -Workload Generic `
               -SizeInGB 50 `
               -Force

# PassThru — capture full resource details
$storage = Invoke-Storage -StoragePoolName 'Pool1' `
                          -VirtualHardDiskName 'VDisk1' `
                          -Workload SQL_MDF `
                          -SizeInGB 500 `
                          -PassThru `
                          -Confirm:$false

Write-Host "Drive:    $($storage.DriveLetter):"
Write-Host "Pool:     $($storage.StoragePool.FriendlyName)"
Write-Host "VDisk:    $($storage.VirtualDisk.FriendlyName)"
Write-Host "Usable:   $($storage.Capacity.UsableGB) GB"
```

### Removal

```powershell
# Remove a single workload stack
Invoke-Storage -StoragePoolName 'ADPool' `
               -VirtualHardDiskName 'NTDS_VDisk' `
               -Workload NTDS `
               -Remove `
               -Confirm:$false
```

### Skip Post-Create Artifacts

```powershell
# Raw volume with no workload directories or marker files
Invoke-Storage -StoragePoolName 'RawPool' `
               -VirtualHardDiskName 'Raw_VDisk' `
               -Workload NTDS `
               -SizeInGB 100 `
               -NoPostCreateArtifacts
```

---

## Architecture

```
Invoke-Storage (Public)          ← ShouldProcess, preflight, logging
    └─ Test-PreflightCheck       ← Windows Server, admin, poolable disks
    └─ New-Storage (Private)     ← Orchestrator + $script:StorageWorkloadProfiles
            ├─ Find-StorageSubSystem     ← Selects best Storage Spaces subsystem
            ├─ Add-StoragePool          ← Idempotent pool creation
            ├─ Add-VirtualDisk          ← Idempotent virtual disk creation
            ├─ Initialize-StorageDisk   ← Online, GPT, partition, drive letter
            ├─ Format-VolumeLabel       ← NTFS label validation + application
            ├─ New-ItemIfAbsent         ← Idempotent directory/file creation
            └─ Remove-Storage           ← Full teardown in reverse order
```

**Key design decisions:**

- **Idempotent** — every creation function checks for existing resources before acting.
- **ShouldProcess hierarchy** — `Invoke-Storage` owns `-WhatIf`/`-Confirm`; private helpers
  use `PSUseShouldProcessForStateChangingFunctions` suppression so `ShouldProcess` context
  flows naturally from the public surface.
- **Cross-platform testable** — all parameters accepting CIM instances use `[object]` so
  Pester can pass `[PSCustomObject]` fakes on macOS/Linux without the Windows Storage module.
- **No module coupling** — Windows-only cmdlets (`Get-Disk`, `Set-Disk`, `New-Partition`, etc.)
  are mocked via global stubs in test `BeforeAll` blocks.

---

## Logging Framework

Seven private functions provide a production-grade, thread-safe logging subsystem:

| Function | Purpose |
|---|---|
| `Write-ToLog` | Core entry point. Timestamped entries to `$script:LogFile` under a named mutex. Levels: `INFO`, `DEBUG`, `WARN`, `ERROR`, `SUCCESS`. Redacts sensitive values. ANSI colour via PSStyle. |
| `Clear-LogFile` | Clears the active log. `ConfirmImpact=High`. `-Archive` saves a timestamped backup first. |
| `Get-LogFilePath` | Returns the current `$script:LogFile` path. |
| `Get-LogFileSize` | Returns log file size in bytes; `0` if the file does not exist. |
| `Invoke-LogRotation` | Shifts numbered backups (`.5` removed, `.4→.5`, …, current→`.1`). Called inside the Write-ToLog mutex. |
| `Set-LogFilePath` | Updates `$script:LogFile` to an absolute path. `-Force` creates the directory. |
| `Write-ErrorLog` | Wraps `[ErrorRecord]` objects: ERROR for the message, DEBUG for type/category/inner exception. `-IncludeStackTrace` appends the script stack. |

Auto-rotates at 10 MB, keeping up to 5 numbered backups. Sensitive data (passwords,
tokens, keys, secrets) is redacted in key=value, JSON, and XML formats before any write.

---

## Building and Testing

```powershell
# First build — resolves all dependencies
./build.ps1 -ResolveDependency -tasks build

# Subsequent builds
$env:ModuleVersion = '0.1.0'
./build.ps1 -tasks build

# Run the full test suite
Invoke-Pester

# Run a specific test file
Invoke-Pester tests/Unit/Public/Invoke-Storage.tests.ps1 -Output Detailed

# Lint — uses PSScriptAnalyzerSettings.psd1 to suppress cross-platform noise
Invoke-ScriptAnalyzer -Path source/ -Recurse -Settings PSScriptAnalyzerSettings.psd1

# Package
./build.ps1 -tasks pack
```

### Test structure

```
tests/
├── QA/
│   └── module.tests.ps1          # ScriptAnalyzer, changelog, help quality
└── Unit/
    ├── Public/
    │   └── Invoke-Storage.tests.ps1
    └── Private/
        ├── Add-StoragePool.tests.ps1
        ├── Add-VirtualDisk.tests.ps1
        ├── Clear-LogFile.tests.ps1
        ├── Find-StorageSubSystem.tests.ps1
        ├── Format-VolumeLabel.tests.ps1
        ├── Get-LogFilePath.tests.ps1
        ├── Get-LogFileSize.tests.ps1
        ├── Initialize-StorageDisk.tests.ps1
        ├── Invoke-LogRotation.tests.ps1
        ├── New-ItemIfAbsent.tests.ps1
        ├── New-Storage.tests.ps1
        ├── Remove-Storage.tests.ps1
        ├── Set-LogFilePath.tests.ps1
        └── Write-ErrorLog.tests.ps1
```

---

## CI/CD

### GitHub Actions

| Workflow | Trigger | Steps |
|---|---|---|
| `ci.yml` | Push to `main`, PRs | Build → Test → ScriptAnalyzer → Coverage |
| `release.yml` | Tag `v*` | Build → Test → Publish to PSGallery → GitHub Release |

**Required secret:** `PSGALLERY_API_KEY`

### Azure Pipelines

`azure-pipelines.yml` runs three stages: **Build** → **Test** (Linux, Windows PS7, macOS)
→ **Deploy** (PSGallery + GitHub Release on `main`).

**Required variables:** `GalleryApiToken`, `GitHubToken`

### Publishing manually

```powershell
# Load credentials (never commit this file)
. ./secrets.local.ps1

./build.ps1 -tasks build
./build.ps1 -tasks publish_psgallery
./build.ps1 -tasks publish_github
```

---

## Directory Structure

```
Invoke-Storage/
├── source/
│   ├── Invoke-Storage.psd1         # Module manifest
│   ├── Invoke-Storage.psm1         # Root module (dot-sources all functions)
│   ├── en-US/
│   │   └── about_Invoke-Storage.help.txt
│   ├── Public/
│   │   └── Invoke-Storage.ps1      # Exported entry point
│   └── Private/
│       ├── Add-StoragePool.ps1
│       ├── Add-VirtualDisk.ps1
│       ├── Clear-Logfile.ps1
│       ├── Find-StorageSubSystem.ps1
│       ├── Format-VolumeLabel.ps1
│       ├── Get-LogFilePath.ps1
│       ├── Get-LogFileSize.ps1
│       ├── Initialize-StorageDisk.ps1
│       ├── Invoke-LogRotation.ps1
│       ├── New-ItemIfAbsent.ps1
│       ├── New-Storage.ps1
│       ├── Remove-Storage.ps1
│       ├── Set-LogFilePath.ps1
│       ├── Test-PreflightCheck.ps1
│       ├── Write-ErroLog.ps1
│       └── Write-ToLog.ps1
├── tests/
│   ├── QA/module.tests.ps1
│   └── Unit/
├── build.ps1
├── build.yaml
├── CHANGELOG.md
├── CLAUDE.md
├── PSScriptAnalyzerSettings.psd1
└── RequiredModules.psd1
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Sampler](https://github.com/gaelcolas/Sampler) — PowerShell module build framework
- [Pester](https://github.com/pester/Pester) — PowerShell testing framework
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) — PowerShell linter
