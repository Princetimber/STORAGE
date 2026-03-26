#Requires -Version 7.0

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

    # Global stubs for Windows-only Volume cmdlets
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

Describe 'Format-VolumeLabel' -Tag 'Unit' {

    Context 'When the label exceeds 32 characters' {
        It 'Should throw a length validation error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $longLabel = 'A' * 33

                { Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel $longLabel } |
                    Should -Throw -ExpectedMessage "*exceeds the maximum length of 32*"
            }
        }
    }

    Context 'When the label contains forbidden characters' {
        It 'Should throw a forbidden-characters error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog

                { Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel 'BAD:LABEL' } |
                    Should -Throw -ExpectedMessage "*contains invalid characters*"
            }
        }
    }

    Context 'When the label contains control characters' {
        It 'Should throw a control-character error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $controlLabel = "LABEL`u{0001}"

                { Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel $controlLabel } |
                    Should -Throw -ExpectedMessage "*contains control characters*"
            }
        }
    }

    Context 'When the volume already has the correct label' {
        It 'Should log INFO and not call Set-Volume' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Volume { return [PSCustomObject]@{ FileSystemLabel = 'SYSVOL' } }
                Mock Set-Volume

                Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel 'SYSVOL'

                Should -Invoke Set-Volume -Times 0
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'INFO' -and $Message -match 'already has label'
                }
            }
        }
    }

    Context 'When the volume has a different label' {
        It 'Should relabel and log SUCCESS' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Volume { return [PSCustomObject]@{ FileSystemLabel = 'OLD' } }
                Mock Set-Volume

                Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel 'SYSVOL'

                Should -Invoke Set-Volume -Times 1 -ParameterFilter {
                    $NewFileSystemLabel -eq 'SYSVOL'
                }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter { $Level -eq 'SUCCESS' }
            }
        }
    }

    Context 'When -WhatIf is passed' {
        It 'Should not call Set-Volume' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Volume { return [PSCustomObject]@{ FileSystemLabel = 'OLD' } }
                Mock Set-Volume

                Format-VolumeLabel -DriveLetter 'D' -FileSystemLabel 'SYSVOL' -WhatIf

                Should -Invoke Set-Volume -Times 0
            }
        }
    }

}
