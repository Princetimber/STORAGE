#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Move-ItemWrapper' -Tag 'Unit' {
    Context 'When moving an item' {
        It 'Should call Move-Item with the given LiteralPath and Destination' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Move-Item

                Move-ItemWrapper -LiteralPath 'C:\Logs\module.log' -Destination 'C:\Logs\module.log.1'

                Should -Invoke Move-Item -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log' -and
                    $Destination -eq 'C:\Logs\module.log.1'
                }
            }
        }
    }

    Context 'When Move-Item fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Move-Item { throw [System.IO.IOException]::new('File in use') }

                { Move-ItemWrapper -LiteralPath 'C:\Logs\module.log' -Destination 'C:\Logs\module.log.1' } | Should -Throw
            }
        }
    }
}
