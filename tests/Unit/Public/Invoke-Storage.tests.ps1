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
    function global:Get-StoragePool {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:Get-VirtualDisk {
        param([string]$FriendlyName, [string]$ErrorAction)
    }
    function global:Get-Volume {
        param([char]$DriveLetter, [string]$ErrorAction)
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Invoke-Storage' -Tag 'Unit' {

    Context 'When preflight EarlyExit is true' {
        It 'Should throw and not call New-Storage' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $true } }
                Mock New-Storage

                { Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                        -Workload 'Generic' -SizeInGB 50 } |
                    Should -Throw -ExpectedMessage '*Preflight checks failed*'

                Should -Invoke New-Storage -Times 0
            }
        }
    }

    Context 'When creation is requested without size parameters' {
        It 'Should throw a fail-fast error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage

                { Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                        -Workload 'Generic' } |
                    Should -Throw -ExpectedMessage '*sizeInGB or -useMaximumSize*'
            }
        }
    }

    Context 'When -WhatIf is passed' {
        It 'Should not call New-Storage' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage

                Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50 -WhatIf

                Should -Invoke New-Storage -Times 0
            }
        }
    }

    Context 'When -Remove is specified' {
        It 'Should call New-Storage with remove parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage

                Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -Remove -Confirm:$false

                Should -Invoke New-Storage -Times 1 -ParameterFilter { $Remove -eq $true }
            }
        }
    }

    Context 'When a successful create completes' {
        It 'Should return the drive letter' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage { return 'D' }

                $result = Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50 -Confirm:$false

                $result | Should -Be 'D'
            }
        }
    }

    Context 'When -PassThru is specified' {
        It 'Should return a PSCustomObject with five properties' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage { return 'D' }
                Mock Get-StoragePool { return [PSCustomObject]@{ FriendlyName = 'Pool1'; Size = 100GB; AllocatedSize = 50GB } }
                Mock Get-VirtualDisk { return [PSCustomObject]@{ FriendlyName = 'VDisk1' } }
                Mock Get-Volume { return [PSCustomObject]@{ DriveLetter = 'D' } }

                $result = Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50 -PassThru -Confirm:$false

                $result.DriveLetter | Should -Be 'D'
                $result.StoragePool | Should -Not -BeNullOrEmpty
                $result.VirtualDisk | Should -Not -BeNullOrEmpty
                $result.Volume | Should -Not -BeNullOrEmpty
                $result.Capacity | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'When -Force is specified' {
        It 'Should set ConfirmPreference to None and proceed without prompt' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Test-PreflightCheck { return @{ EarlyExit = $false } }
                Mock New-Storage { return 'E' }

                # Force suppresses ShouldProcess — no -Confirm:$false needed
                $result = Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' `
                    -Workload 'Generic' -SizeInGB 50 -Force

                Should -Invoke New-Storage -Times 1
                $result | Should -Be 'E'
            }
        }
    }
}
