#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Initialize-LogFilePath' -Tag 'Unit' {
    BeforeEach {
        InModuleScope -ModuleName $script:dscModuleName {
            $script:savedGlobalLogFile = $Global:LogFile
            $Global:LogFile = $null
        }
    }

    AfterEach {
        InModuleScope -ModuleName $script:dscModuleName {
            $Global:LogFile = $script:savedGlobalLogFile
        }
    }

    Context 'When $Global:LogFile is not already set' {
        It 'Should create a default path under the temp directory and set $Global:LogFile' {
            InModuleScope -ModuleName $script:dscModuleName {
                $result = Initialize-LogFilePath

                $result | Should -Match ([regex]::Escape([System.IO.Path]::GetTempPath()))
                $result | Should -Match 'Invoke-Storage_\d{8}_\d{6}\.log$'
                $Global:LogFile | Should -Be $result
            }
        }
    }

    Context 'When $Global:LogFile is already set' {
        It 'Should return the existing value without changing it' {
            InModuleScope -ModuleName $script:dscModuleName {
                $Global:LogFile = 'C:\Existing\module.log'

                $result = Initialize-LogFilePath

                $result | Should -Be 'C:\Existing\module.log'
            }
        }
    }
}
