#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Find-StorageSubSystem' -Tag 'Unit' {

    Context 'When no subsystems are found' {
        It 'Should return nothing and log a WARN message' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog

                $result = Find-StorageSubSystem -SubSystems @()

                $result | Should -BeNullOrEmpty
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'WARN' -and $Message -match 'No Storage SubSystem found'
                }
            }
        }
    }

    Context 'When a single subsystem is found' {
        It 'Should return that subsystem' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $fakeSubSystem = [PSCustomObject]@{ FriendlyName = 'Storage Spaces'; Model = 'Model1' }

                $result = Find-StorageSubSystem -SubSystems @($fakeSubSystem)

                $result.FriendlyName | Should -Be 'Storage Spaces'
            }
        }
    }

    Context 'When multiple subsystems exist and one matches "Windows Storage*"' {
        It 'Should return the preferred subsystem and log INFO' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $preferred   = [PSCustomObject]@{ FriendlyName = 'Windows Storage'; Model = 'WinModel' }
                $otherSystem = [PSCustomObject]@{ FriendlyName = 'Other Storage';   Model = 'OtherModel' }

                $result = Find-StorageSubSystem -SubSystems @($preferred, $otherSystem)

                $result.FriendlyName | Should -Be 'Windows Storage'
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'INFO' -and $Message -match 'Using preferred subsystem'
                }
            }
        }
    }

    Context 'When multiple subsystems exist but none matches "Windows Storage*"' {
        It 'Should log ERROR with available list, log WARN fallback, and return the first subsystem' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                $first  = [PSCustomObject]@{ FriendlyName = 'Storage A'; Model = 'ModelA' }
                $second = [PSCustomObject]@{ FriendlyName = 'Storage B'; Model = 'ModelB' }

                $result = Find-StorageSubSystem -SubSystems @($first, $second)

                $result.FriendlyName | Should -Be 'Storage A'
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'ERROR' -and $Message -match 'no preferred Windows Storage SubSystem'
                }
                Should -Invoke Write-ToLog -Times 1 -ParameterFilter {
                    $Level -eq 'WARN' -and $Message -match 'Falling back'
                }
            }
        }
    }

}
