BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    if (-not (Get-Module -Name $script:dscModuleName)) {
        $outputManifest = Join-Path $PSScriptRoot '../../../output/module/Invoke-Storage' |
            Get-ChildItem -Filter 'Invoke-Storage.psd1' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -Last 1

        if ($outputManifest) {
            Import-Module -Name $outputManifest.FullName -Force
        }
        else {
            Import-Module -Name $script:dscModuleName
        }
    }

    # Windows-only stubs
    function global:Get-VirtualDisk {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:Get-Disk {
        param([string]$ErrorAction)
    }
    function global:Get-Partition {
        param([int]$DiskNumber, [string]$ErrorAction)
    }
    function global:Remove-Partition {
        param([bool]$Confirm, [string]$ErrorAction)
    }
    function global:Set-Disk {
        param([int]$Number, [bool]$IsOffline, [string]$ErrorAction)
    }
    function global:Remove-VirtualDisk {
        param([string]$FriendlyName, [bool]$Confirm, [string]$ErrorAction)
    }
    function global:Get-StoragePool {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:Remove-StoragePool {
        param([string]$FriendlyName, [bool]$Confirm, [string]$ErrorAction)
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Remove-Storage' -Tag 'Unit' {

    Context 'When the VHD does not exist' {
        It 'Should not call any removal cmdlets' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock Remove-VirtualDisk
                Mock Get-StoragePool { return $null }
                Mock Remove-StoragePool

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'Generic'

                Should -Invoke Remove-VirtualDisk -Times 0
                Should -Invoke Remove-StoragePool -Times 0
            }
        }
    }

    Context 'When the VHD exists and the disk is already offline' {
        It 'Should not call Set-Disk to set offline' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 1; IsOffline = $true }
                $fakeVhd = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $fakeVhd }
                Mock Get-Disk { return $fakeDisk }
                Mock Get-Partition { return @() }
                Mock Remove-Partition
                Mock Set-Disk
                Mock Remove-VirtualDisk
                Mock Get-StoragePool { return $null }

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'Generic'

                Should -Invoke Set-Disk -Times 0
            }
        }
    }

    Context 'When the VHD exists and partitions are present' {
        It 'Should remove partitions before removing the VHD' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 2; IsOffline = $false }
                $fakeVhd = [PSCustomObject]@{ FriendlyName = 'VDisk1' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'D' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $fakeVhd }
                Mock Get-Disk { return $fakeDisk }
                Mock Get-Partition { return $fakePartition }
                Mock Remove-Partition
                Mock Set-Disk
                Mock Remove-VirtualDisk
                Mock Get-StoragePool { return $null }

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'Generic'

                Should -Invoke Remove-Partition -Times 1
                Should -Invoke Remove-VirtualDisk -Times 1
            }
        }
    }

    Context 'When the pool has remaining virtual disks' {
        It 'Should not remove the pool' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakePool = [PSCustomObject]@{ FriendlyName = 'Pool1' }
                $remainingVD = [PSCustomObject]@{ FriendlyName = 'OtherDisk' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock Get-StoragePool { return $fakePool }
                Mock Remove-StoragePool

                # Mock the pipeline call $pool | Get-VirtualDisk
                Mock Get-VirtualDisk { return $remainingVD }

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'Generic'

                Should -Invoke Remove-StoragePool -Times 0
            }
        }
    }

    Context 'When the pool has no remaining virtual disks' {
        It 'Should remove the pool' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakePool = [PSCustomObject]@{ FriendlyName = 'Pool1' }

                Mock Write-ToLog
                # First call (Get-VirtualDisk -FriendlyName) returns null — VHD gone
                Mock Get-VirtualDisk { return $null }
                Mock Get-StoragePool { return $fakePool }
                # Pipeline call ($pool | Get-VirtualDisk) returns nothing — pool empty
                Mock Get-VirtualDisk { return $null }
                Mock Remove-StoragePool
                Mock Start-Sleep

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'Generic'

                Should -Invoke Remove-StoragePool -Times 1 -ParameterFilter {
                    $FriendlyName -eq 'Pool1'
                }
            }
        }
    }

    Context 'When the workload has RootFiles' {
        It 'Should call Remove-Item for each root file' {
            InModuleScope -ModuleName $script:dscModuleName {
                # Inject a minimal profile into the module-scoped hashtable
                $script:StorageWorkloadProfiles = @{
                    'TestWorkload' = @{
                        RootFiles  = @('C:\marker.sms')
                        DriveFiles = @()
                    }
                }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock Get-StoragePool { return $null }
                Mock Remove-Item

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'TestWorkload'

                Should -Invoke Remove-Item -Times 1 -ParameterFilter { $Path -eq 'C:\marker.sms' }
            }
        }
    }

    Context 'When the workload has DriveFiles' {
        It 'Should call Remove-Item for each file per partition drive letter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $script:StorageWorkloadProfiles = @{
                    'DriveWorkload' = @{
                        RootFiles  = @()
                        DriveFiles = @('no_sms_on_drive.sms')
                    }
                }

                $fakeDisk = [PSCustomObject]@{ Number = 3; IsOffline = $false }
                $fakeVhd = [PSCustomObject]@{ FriendlyName = 'VDisk1' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'D' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $fakeVhd }
                Mock Get-Disk { return $fakeDisk }
                Mock Get-Partition { return $fakePartition }
                Mock Remove-Partition
                Mock Set-Disk
                Mock Remove-VirtualDisk
                Mock Get-StoragePool { return $null }
                Mock Remove-Item

                Remove-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload 'DriveWorkload'

                Should -Invoke Remove-Item -Times 1 -ParameterFilter {
                    $Path -eq 'D:\no_sms_on_drive.sms'
                }
            }
        }
    }
}
