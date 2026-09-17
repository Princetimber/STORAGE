#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Add-ContentWrapper' -Tag 'Unit' {
    Context 'When appending content' {
        It 'Should call Add-Content with the given LiteralPath and Value' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Add-Content

                Add-ContentWrapper -LiteralPath 'C:\Logs\module.log' -Value 'log entry'

                Should -Invoke Add-Content -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log' -and $Value -eq 'log entry'
                }
            }
        }
    }

    Context 'When Add-Content fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Add-Content { throw [System.UnauthorizedAccessException]::new('Access denied') }

                { Add-ContentWrapper -LiteralPath 'C:\Logs\module.log' -Value 'log entry' } | Should -Throw
            }
        }
    }
}
