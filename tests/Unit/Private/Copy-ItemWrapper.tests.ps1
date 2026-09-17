#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Copy-ItemWrapper' -Tag 'Unit' {
    Context 'When copying an item' {
        It 'Should call Copy-Item with the given LiteralPath and Destination' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Copy-Item

                Copy-ItemWrapper -LiteralPath 'C:\Logs\module.log' -Destination 'C:\Logs\module.log.bak'

                Should -Invoke Copy-Item -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log' -and
                    $Destination -eq 'C:\Logs\module.log.bak'
                }
            }
        }
    }

    Context 'When Copy-Item fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Copy-Item { throw [System.IO.IOException]::new('Disk full') }

                { Copy-ItemWrapper -LiteralPath 'C:\Logs\module.log' -Destination 'C:\Logs\module.log.bak' } | Should -Throw
            }
        }
    }
}
