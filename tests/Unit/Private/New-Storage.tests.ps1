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
    function global:Get-StorageSubSystem {
        param([string]$ErrorAction)
    }
    function global:Get-Volume {
        param([char]$DriveLetter, [string]$ErrorAction)
    }
    function global:Set-Volume {
        param([char]$DriveLetter, [string]$NewFileSystemLabel, [string]$ErrorAction)
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'New-Storage' -Tag 'Unit' {

    Context 'When -Remove is specified' {
        It 'Should call Remove-Storage and return without creating resources' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Remove-Storage
                Mock Add-StoragePool
                Mock Add-VirtualDisk

                New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -Remove

                Should -Invoke Remove-Storage -Times 1 -ParameterFilter {
                    $StoragePoolName -eq 'Pool1' -and
                    $VirtualHardDiskName -eq 'VDisk1' -and
                    $Workload -eq 'Generic'
                }
                Should -Invoke Add-StoragePool -Times 0
                Should -Invoke Add-VirtualDisk -Times 0
            }
        }
    }

    Context 'When neither sizeInGB nor useMaximumSize is specified' {
        It 'Should throw a fail-fast error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }

                {
                    New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                        -Workload 'Generic'
                } | Should -Throw -ExpectedMessage '*Either sizeInGB or useMaximumSize*'
            }
        }
    }

    Context 'When a successful create path runs with sizeInGB' {
        It 'Should call the full provisioning pipeline and return a drive letter' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }
                Mock Add-StoragePool
                Mock Add-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Initialize-StorageDisk { return 'D' }
                Mock Format-VolumeLabel
                Mock New-ItemIfAbsent

                $result = New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50

                $result | Should -Be 'D'
                Should -Invoke Add-StoragePool -Times 1
                Should -Invoke Add-VirtualDisk -Times 1
                Should -Invoke Initialize-StorageDisk -Times 1
                Should -Invoke Format-VolumeLabel -Times 1
            }
        }
    }

    Context 'When useMaximumSize is specified' {
        It 'Should pass useMaximumSize to Add-VirtualDisk' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }
                Mock Add-StoragePool
                Mock Add-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Initialize-StorageDisk { return 'E' }
                Mock Format-VolumeLabel
                Mock New-ItemIfAbsent

                New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -UseMaximumSize

                Should -Invoke Add-VirtualDisk -Times 1 -ParameterFilter { $UseMaximumSize -eq $true }
            }
        }
    }

    Context 'When -NoPostCreateArtifacts is specified' {
        It 'Should not call New-ItemIfAbsent' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }
                Mock Add-StoragePool
                Mock Add-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Initialize-StorageDisk { return 'F' }
                Mock Format-VolumeLabel
                Mock New-ItemIfAbsent

                New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'NTDS' -SizeInGB 50 -NoPostCreateArtifacts

                Should -Invoke New-ItemIfAbsent -Times 0
            }
        }
    }

    Context 'When a workload with Directories is provisioned' {
        It 'Should call New-ItemIfAbsent for each directory' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }
                Mock Add-StoragePool
                Mock Add-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Initialize-StorageDisk { return 'D' }
                Mock Format-VolumeLabel
                Mock New-ItemIfAbsent

                # NTDS has 2 directories
                New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'NTDS' -SizeInGB 50

                Should -Invoke New-ItemIfAbsent -Times 2 -ParameterFilter { $Type -eq 'Directory' }
            }
        }
    }

    Context 'When a custom fileSystemLabel is provided' {
        It 'Should pass the custom label to Format-VolumeLabel' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StorageSubSystem { return @([PSCustomObject]@{ FriendlyName = 'Sub1' }) }
                Mock Find-StorageSubSystem { return [PSCustomObject]@{ FriendlyName = 'Sub1' } }
                Mock Add-StoragePool
                Mock Add-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Initialize-StorageDisk { return 'D' }
                Mock Format-VolumeLabel
                Mock New-ItemIfAbsent

                New-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50 -FileSystemLabel 'MYDATA'

                Should -Invoke Format-VolumeLabel -Times 1 -ParameterFilter {
                    $FileSystemLabel -eq 'MYDATA'
                }
            }
        }
    }
}
