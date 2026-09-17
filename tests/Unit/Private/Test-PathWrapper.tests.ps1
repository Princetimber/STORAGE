#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Test-PathWrapper' -Tag 'Unit' {
    Context 'When called with -LiteralPath' {
        It 'Should call Test-Path with -LiteralPath' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { $true }

                $result = Test-PathWrapper -LiteralPath 'C:\Logs\module.log'

                $result | Should -BeTrue
                Should -Invoke Test-Path -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log'
                }
            }
        }
    }

    Context 'When called with -Path only' {
        It 'Should call Test-Path with -Path' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { $false }

                $result = Test-PathWrapper -Path 'C:\Logs'

                $result | Should -BeFalse
                Should -Invoke Test-Path -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Logs'
                }
            }
        }
    }

    Context 'When called with -Path and -PathType' {
        It 'Should call Test-Path with -Path and -PathType' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { $true }

                $result = Test-PathWrapper -Path 'C:\Logs' -PathType Container

                $result | Should -BeTrue
                Should -Invoke Test-Path -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Logs' -and $PathType -eq 'Container'
                }
            }
        }
    }
}
