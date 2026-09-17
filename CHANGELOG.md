# Changelog for Invoke-Storage

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- `RequiredModules.psd1`: the `Sampler.GitHubTasks` version range `[0.6,1.0)` did not match
  any version ever published to PSGallery (latest is 0.4.1), breaking the CI Build job on
  every run since March 2026. Relaxed to `[0.4,1.0)`.

### Changed

- CI: restricted the `test` job to `windows-latest` only, since this module wraps Windows-only
  Storage Spaces cmdlets that do not exist on Linux/macOS.

### Known issues

- Fixing the `Sampler.GitHubTasks` pin exposed a second, unrelated CI failure: PSDepend's
  bootstrap phase fails on the `ubuntu-latest` Build job with
  `Install-Package: Administrator rights are required to install or update`, independent of
  this fix. Root cause and resolution are still being investigated — CI cannot currently
  complete a Build on this repository even with this fix applied.

## [0.0.2] - 2026-03-26

### Fixed

- `Write-ToLog`: corrected default log filename from `Invoke-ADDSDomainController_*.log` to
  `Invoke-Storage_*.log` — Storage module logs were being written with the wrong module name prefix.
- `Write-ToLog`: corrected named mutex from `Global\Invoke-ADDSDomainControllerLog` to
  `Global\Invoke-StorageLog` — the wrong mutex name would have caused ADDS and Storage modules
  to share a system mutex, serialising each other's log writes.
- `Write-ToLog`: corrected inline comment referencing `Invoke-ADDSDomainController`.

### Published

- Patch release to PowerShell Gallery as `Invoke-Storage` v0.0.2.

## [0.0.1] - 2026-03-26

### Added

- `Invoke-Storage` public function — entry point for creating and removing Storage Spaces
  resources. Supports WhatIf/Confirm (ConfirmImpact=High), -Force, -PassThru, and runs
  preflight checks before any operation.
- `New-Storage` private orchestrator — creates a full storage stack (pool → virtual disk →
  volume → label → artifacts) or delegates to Remove-Storage when -Remove is specified.
  Defines `$script:StorageWorkloadProfiles` with 10 built-in workload entries (SYSVOL,
  NTDS, ConfigMgrInstall, ApplicationSources, ContentLibrary, SQL_MDF, SQL_LDF, TempDB,
  WSUSDB, Generic).
- `Initialize-StorageDisk` private function — brings a virtual disk online, clears
  read-only flag, initialises as GPT if RAW, creates a partition if none exists, returns
  the assigned drive letter.
- `Remove-Storage` private function — tears down partitions, virtual disk, workload
  marker files, and storage pool (when empty) in reverse-creation order. Idempotent.
- `Add-StoragePool` private function — idempotently creates a Windows Storage Spaces pool.
  Inlines disk-count validation for Simple/Mirror/Parity resiliency.
- `Add-VirtualDisk` private function — idempotently creates a virtual disk. Handles
  Simple+UseMaximumSize → Fixed provisioning edge case.
- `Find-StorageSubSystem` private function — selects the best Storage Spaces subsystem,
  preferring names matching "Windows Storage*" when multiple exist.
- `Format-VolumeLabel` private function — validates and applies an NTFS volume label.
  Inlines Assert-NTFSVolumeLabel guards (length, forbidden characters, control characters).
  Idempotent.
- `New-ItemIfAbsent` private function — idempotently creates a directory or file.
  Supports -Hidden switch for marking system directories.
- `Test-PreflightCheck` private function — validates Windows Server platform, admin
  privileges, and poolable disk availability before any storage operation.
- `Clear-LogFile` private function — clears the active log file with optional
  timestamped archive backup. ConfirmImpact=High.
- `Get-LogFilePath` private function — returns the current module-scoped log file path.
- `Get-LogFileSize` private function — returns the log file size in bytes; 0 if absent.
- `Invoke-LogRotation` private function — shifts numbered backup files (log.4 removed,
  log.3→log.4, …, log→log.1). Called inside the Write-ToLog mutex.
- `Set-LogFilePath` private function — sets the module-scoped log file path with
  absolute-path validation; -Force creates the destination directory on demand.
- `Write-ErrorLog` private function — wrapper around Write-ToLog for ErrorRecord objects.
  Logs message at ERROR; exception type, category, and inner exception at DEBUG.
  -IncludeStackTrace appends the PowerShell script stack trace.
- `Write-ToLog` private function — thread-safe structured logging with named mutex,
  auto-rotation at 10 MB (5 backups), sensitive-data redaction, and ANSI colour output.
- Unit tests for all functions (54 tests, 0 failures).

### Changed

- Removed `Assert-NTFSVolumeLabel` — validation inlined into `Format-VolumeLabel`.
- Removed `Get-RequiredDiskCountForResiliency` — disk-count logic inlined into
  `Add-StoragePool`.
- Renamed `New-DirectoryIfExistOrNot` → `New-ItemIfAbsent`; merged `New-FileIfExistOrNot`
  into the same function.
- Pinned dependency versions in RequiredModules.psd1 using version ranges.
- Updated README with full module documentation, workload profile reference, architecture
  diagram, usage examples, and build/test instructions.
- Updated `about_Invoke-Storage.help.txt` with command list, parameter reference, and
  six usage examples.

### Removed

- `Assert-NTFSVolumeLabel`, `Get-RequiredDiskCountForResiliency`, `New-DirectoryIfExistOrNot`,
  `New-FileIfExistOrNot` — replaced by the functions listed above.

### Published

- Initial release to PowerShell Gallery as `Invoke-Storage` v0.0.1.
