#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Get-ItemWrapper' -Tag 'Unit' {
    Context 'When the item exists' {
        It 'Should call Get-Item with the given LiteralPath and return the result' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-Item { [PSCustomObject]@{ FullName = 'C:\Logs\module.log'; Length = 1024 } }

                $result = Get-ItemWrapper -LiteralPath 'C:\Logs\module.log'

                $result.Length | Should -Be 1024
                Should -Invoke Get-Item -Times 1 -ParameterFilter {
                    $LiteralPath -eq 'C:\Logs\module.log'
                }
            }
        }
    }

    Context 'When the item does not exist' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Get-Item { throw [System.Management.Automation.ItemNotFoundException]::new('Not found') }

                { Get-ItemWrapper -LiteralPath 'C:\Logs\missing.log' } | Should -Throw
            }
        }
    }
}
