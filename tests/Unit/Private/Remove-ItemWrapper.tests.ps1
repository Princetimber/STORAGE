#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Remove-ItemWrapper' -Tag 'Unit' {
    Context 'When removing an item' {
        It 'Should call Remove-Item with the given LiteralPath' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Remove-Item

                Remove-ItemWrapper -LiteralPath 'C:\Logs\module.log.5'

                Should -Invoke Remove-Item -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log.5'
                }
            }
        }
    }

    Context 'When Remove-Item fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Remove-Item { throw [System.UnauthorizedAccessException]::new('Access denied') }

                { Remove-ItemWrapper -LiteralPath 'C:\Logs\module.log.5' } | Should -Throw
            }
        }
    }
}
