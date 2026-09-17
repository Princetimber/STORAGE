#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Clear-ContentWrapper' -Tag 'Unit' {
    Context 'When clearing content' {
        It 'Should call Clear-Content with the given LiteralPath' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Clear-Content

                Clear-ContentWrapper -LiteralPath 'C:\Logs\module.log'

                Should -Invoke Clear-Content -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log'
                }
            }
        }
    }

    Context 'When Clear-Content fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Clear-Content { throw [System.UnauthorizedAccessException]::new('Access denied') }

                { Clear-ContentWrapper -LiteralPath 'C:\Logs\module.log' } | Should -Throw
            }
        }
    }
}
