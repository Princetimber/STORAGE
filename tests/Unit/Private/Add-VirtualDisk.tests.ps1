#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    # Import by name (works when Sampler sets PSModulePath); fall back to output path for direct runs
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

    # Global stubs for Windows-only Storage cmdlets — param() declarations required
    # so Pester ParameterFilter can bind named arguments on macOS/Linux
    function global:Get-VirtualDisk {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:New-VirtualDisk {
        param(
            [string]$FriendlyName,
            [string]$StoragePoolFriendlyName,
            [string]$ResiliencySettingName,
            [string]$ProvisioningType,
            [int]$NumberOfColumns,
            [Int64]$Size,
            [switch]$UseMaximumSize,
            [string]$ErrorAction
        )
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Add-VirtualDisk' -Tag 'Unit' {

    Context 'When the virtual disk already exists' {
        It 'Should return the existing disk without creating a new one' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeVDisk = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $fakeVDisk } -ParameterFilter { $FriendlyName -eq 'VDisk1' }
                Mock New-VirtualDisk

                $result = Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' -Size 10GB

                $result.FriendlyName | Should -Be 'VDisk1'
                Should -Invoke New-VirtualDisk -Times 0
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'WARN' -and $Message -match 'already exists'
                }
            }
        }
    }

    Context 'When Simple resiliency and UseMaximumSize are combined' {
        It 'Should force ProvisioningType to Fixed and log a warning' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeVDisk = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock New-VirtualDisk { return $fakeVDisk }

                Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' `
                    -ResiliencySettingName 'Simple' -UseMaximumSize

                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'WARN' -and $Message -match 'Forcing ProvisioningType = Fixed'
                }
                Should -Invoke New-VirtualDisk -Times 1 -ParameterFilter {
                    $ProvisioningType -eq 'Fixed'
                }
            }
        }
    }

    Context 'When neither Size nor UseMaximumSize is specified' {
        It 'Should throw a missing-Size error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }

                { Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' } |
                    Should -Throw -ExpectedMessage "*Either -Size or -UseMaximumSize*"
            }
        }
    }

    Context 'When an explicit Size is provided' {
        It 'Should create the virtual disk with the specified size' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeVDisk = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock New-VirtualDisk { return $fakeVDisk }

                $result = Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' `
                    -ResiliencySettingName 'Mirror' -Size 50GB

                $result.FriendlyName | Should -Be 'VDisk1'
                Should -Invoke New-VirtualDisk -Times 1 -ParameterFilter { $Size -eq 50GB }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter { $Level -eq 'SUCCESS' }
            }
        }
    }

    Context 'When UseMaximumSize is specified with non-Simple resiliency' {
        It 'Should create the virtual disk using maximum pool size' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeVDisk = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock New-VirtualDisk { return $fakeVDisk }

                $result = Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' `
                    -ResiliencySettingName 'Mirror' -UseMaximumSize

                $result.FriendlyName | Should -Be 'VDisk1'
                Should -Invoke New-VirtualDisk -Times 1 -ParameterFilter { $UseMaximumSize -eq $true }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter { $Level -eq 'SUCCESS' }
            }
        }
    }

    Context 'When Simple resiliency is used' {
        It 'Should set NumberOfColumns to 1' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeVDisk = [PSCustomObject]@{ FriendlyName = 'VDisk1' }

                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock New-VirtualDisk { return $fakeVDisk }

                Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' `
                    -ResiliencySettingName 'Simple' -Size 20GB

                Should -Invoke New-VirtualDisk -Times 1 -ParameterFilter { $NumberOfColumns -eq 1 }
            }
        }
    }

    Context 'When -WhatIf is passed' {
        It 'Should not call New-VirtualDisk' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-VirtualDisk { return $null }
                Mock New-VirtualDisk

                Add-VirtualDisk -StoragePoolName 'Pool1' -VirtualDiskName 'VDisk1' `
                    -Size 10GB -WhatIf

                Should -Invoke New-VirtualDisk -Times 0
            }
        }
    }

}
