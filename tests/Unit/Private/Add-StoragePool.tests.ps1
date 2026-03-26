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

    # Global stubs for Windows-only Storage cmdlets — Pester ParameterFilter requires
    # formal param declarations to bind named arguments for matching on macOS/Linux
    function global:Get-StoragePool {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:Get-PhysicalDisk {
        param([string]$StoragePoolFriendlyName, [bool]$CanPool, [string]$ErrorAction)
    }
    function global:New-StoragePool {
        param(
            [string]$FriendlyName,
            [string]$StorageSubSystemFriendlyName,
            [object[]]$PhysicalDisks,
            [string]$ErrorAction
        )
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Add-StoragePool' -Tag 'Unit' {

    Context 'When the pool already exists and has sufficient disks' {
        It 'Should return the existing pool without creating a new one' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakePool = [PSCustomObject]@{
                    FriendlyName                 = 'Pool1'
                    StorageSubSystemFriendlyName = 'Windows Storage'
                }
                $fakeDisks = @(
                    [PSCustomObject]@{ FriendlyName = 'Disk1' }
                    [PSCustomObject]@{ FriendlyName = 'Disk2' }
                )

                Mock Write-ToLog
                Mock Get-StoragePool { return $fakePool }
                Mock Get-PhysicalDisk { return $fakeDisks } -ParameterFilter { $StoragePoolFriendlyName -eq 'Pool1' }
                Mock New-StoragePool

                $result = Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Mirror'

                $result.FriendlyName | Should -Be 'Pool1'
                Should -Invoke New-StoragePool -Times 0
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'WARN' -and $Message -match 'already exists'
                }
            }
        }
    }

    Context 'When the pool already exists but has too few disks' {
        It 'Should throw a disk-count error' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakePool = [PSCustomObject]@{
                    FriendlyName                 = 'Pool1'
                    StorageSubSystemFriendlyName = 'Windows Storage'
                }

                Mock Write-ToLog
                Mock Get-StoragePool { return $fakePool }
                # Only 1 disk present, Mirror requires 2
                Mock Get-PhysicalDisk {
                    return @([PSCustomObject]@{ FriendlyName = 'Disk1' })
                } -ParameterFilter { $StoragePoolFriendlyName -eq 'Pool1' }

                { Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Mirror' } |
                    Should -Throw -ExpectedMessage "*Mirror*requires at least 2*"
            }
        }
    }

    Context 'When the pool does not exist and no poolable disks are found' {
        It 'Should throw a no-disks error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                Mock Get-PhysicalDisk { return $null } -ParameterFilter { $CanPool -eq $true }

                { Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Simple' } |
                    Should -Throw -ExpectedMessage "*No poolable disks found*"
            }
        }
    }

    Context 'When the pool does not exist and poolable disk count is insufficient' {
        It 'Should throw an insufficient-disks error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                # Only 1 poolable disk, Parity requires 3
                Mock Get-PhysicalDisk {
                    return @([PSCustomObject]@{ FriendlyName = 'Disk1'; MediaType = 'HDD'; Size = 1GB })
                } -ParameterFilter { $CanPool -eq $true }

                { Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Parity' } |
                    Should -Throw -ExpectedMessage "*Insufficient poolable disks*"
            }
        }
    }

    Context 'When the pool does not exist and auto-selection is used' {
        It 'Should create the pool with SSD-first sorted disk selection' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeNewPool = [PSCustomObject]@{ FriendlyName = 'Pool1' }
                $poolableDisks = @(
                    [PSCustomObject]@{ FriendlyName = 'HDD-A'; MediaType = 'HDD'; Size = 2GB },
                    [PSCustomObject]@{ FriendlyName = 'SSD-B'; MediaType = 'SSD'; Size = 1GB }
                )

                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                Mock Get-PhysicalDisk { return $poolableDisks } -ParameterFilter { $CanPool -eq $true }
                Mock New-StoragePool { return $fakeNewPool }

                $result = Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Simple'

                $result.FriendlyName | Should -Be 'Pool1'
                # Simple resiliency selects 1 disk — must be the SSD (SSD-first sort)
                Should -Invoke New-StoragePool -Times 1 -ParameterFilter {
                    $PhysicalDisks[0].FriendlyName -eq 'SSD-B'
                }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter { $Level -eq 'SUCCESS' }
            }
        }
    }

    Context 'When caller supplies fewer disks than required' {
        It 'Should throw a supplied-disk-count error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                $oneDisks = @([PSCustomObject]@{ FriendlyName = 'Disk1'; Size = 1GB })

                { Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Mirror' `
                    -PhysicalDisks $oneDisks } |
                    Should -Throw -ExpectedMessage "*Supplied 1 disk(s)*Mirror*requires at least 2*"
            }
        }
    }

    Context 'When caller supplies sufficient disks' {
        It 'Should create the pool using the supplied disks' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeNewPool = [PSCustomObject]@{ FriendlyName = 'Pool1' }
                $suppliedDisks = @(
                    [PSCustomObject]@{ FriendlyName = 'Disk1'; Size = 2GB },
                    [PSCustomObject]@{ FriendlyName = 'Disk2'; Size = 2GB }
                )

                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                Mock New-StoragePool { return $fakeNewPool }

                $result = Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Mirror' `
                    -PhysicalDisks $suppliedDisks

                $result.FriendlyName | Should -Be 'Pool1'
                Should -Invoke New-StoragePool -Times 1 -ParameterFilter { $PhysicalDisks.Count -eq 2 }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter { $Level -eq 'SUCCESS' }
            }
        }
    }

    Context 'When -WhatIf is passed' {
        It 'Should not call New-StoragePool' {
            InModuleScope -ModuleName $script:dscModuleName {
                # Supply disks directly to isolate ShouldProcess — no auto-select path needed
                $suppliedDisks = @([PSCustomObject]@{ FriendlyName = 'Disk1'; Size = 1GB })

                Mock Write-ToLog
                Mock Get-StoragePool { return $null }
                Mock New-StoragePool

                Add-StoragePool -StorageSubSystemFriendlyName 'Windows Storage' `
                    -StoragePoolName 'Pool1' -ResiliencySettingName 'Simple' `
                    -PhysicalDisks $suppliedDisks -WhatIf

                Should -Invoke New-StoragePool -Times 0
            }
        }
    }

}
