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

    # Windows-only stubs so Pester can mock on macOS/Linux
    function global:Get-Disk {
        param([string]$ErrorAction)
    }
    function global:Set-Disk {
        param([int]$Number, [bool]$IsOffline, [bool]$IsReadOnly, [string]$ErrorAction)
    }
    function global:Initialize-Disk {
        param([int]$Number, [string]$PartitionStyle, [string]$ErrorAction)
    }
    function global:Get-Partition {
        param([int]$DiskNumber)
    }
    function global:New-Partition {
        param([int]$DiskNumber, [switch]$UseMaximumSize, [switch]$AssignDriveLetter, [string]$ErrorAction)
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Initialize-StorageDisk' -Tag 'Unit' {

    Context 'When the disk is offline' {
        It 'Should call Set-Disk to bring it online' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 1; Offline = $true; IsReadOnly = $false; PartitionStyle = 'GPT' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'D' }

                Mock Get-Disk { return $fakeDisk }
                Mock Set-Disk
                Mock Get-Partition { return $fakePartition }
                Mock Write-ToLog

                Initialize-StorageDisk -VirtualHardDisk ([PSCustomObject]@{})

                Should -Invoke Set-Disk -Times 1 -ParameterFilter { $IsOffline -eq $false }
            }
        }
    }

    Context 'When the disk is read-only' {
        It 'Should call Set-Disk to clear the read-only flag' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 2; Offline = $false; IsReadOnly = $true; PartitionStyle = 'GPT' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'E' }

                Mock Get-Disk { return $fakeDisk }
                Mock Set-Disk
                Mock Get-Partition { return $fakePartition }
                Mock Write-ToLog

                Initialize-StorageDisk -VirtualHardDisk ([PSCustomObject]@{})

                Should -Invoke Set-Disk -Times 1 -ParameterFilter { $IsReadOnly -eq $false }
            }
        }
    }

    Context 'When the disk partition style is RAW' {
        It 'Should call Initialize-Disk with GPT' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 3; Offline = $false; IsReadOnly = $false; PartitionStyle = 'RAW' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'F' }

                Mock Get-Disk { return $fakeDisk }
                Mock Initialize-Disk
                Mock Get-Partition { return $fakePartition }
                Mock Write-ToLog

                Initialize-StorageDisk -VirtualHardDisk ([PSCustomObject]@{})

                Should -Invoke Initialize-Disk -Times 1 -ParameterFilter { $PartitionStyle -eq 'GPT' }
            }
        }
    }

    Context 'When a partition with a drive letter already exists' {
        It 'Should return the existing drive letter and not call New-Partition' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 4; Offline = $false; IsReadOnly = $false; PartitionStyle = 'GPT' }
                $fakePartition = [PSCustomObject]@{ DriveLetter = 'D' }

                Mock Get-Disk { return $fakeDisk }
                Mock Get-Partition { return $fakePartition }
                Mock New-Partition
                Mock Write-ToLog

                $result = Initialize-StorageDisk -VirtualHardDisk ([PSCustomObject]@{})

                $result | Should -Be 'D'
                Should -Invoke New-Partition -Times 0
            }
        }
    }

    Context 'When no partition exists' {
        It 'Should call New-Partition and return the assigned drive letter' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeDisk = [PSCustomObject]@{ Number = 5; Offline = $false; IsReadOnly = $false; PartitionStyle = 'GPT' }
                $newPartition = [PSCustomObject]@{ DriveLetter = 'G' }

                Mock Get-Disk { return $fakeDisk }
                Mock Get-Partition { return @() }
                Mock New-Partition { return $newPartition }
                Mock Write-ToLog

                $result = Initialize-StorageDisk -VirtualHardDisk ([PSCustomObject]@{})

                Should -Invoke New-Partition -Times 1 -ParameterFilter {
                    $UseMaximumSize -eq $true -and $AssignDriveLetter -eq $true
                }
                $result | Should -Be 'G'
            }
        }
    }
}
