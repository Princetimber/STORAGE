#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'New-ItemDirectoryWrapper' -Tag 'Unit' {
    Context 'When creating a directory' {
        It 'Should call New-Item with -ItemType Directory and return the result' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-Item { [System.IO.DirectoryInfo]::new($Path) }

                $result = New-ItemDirectoryWrapper -Path 'C:\Logs'

                $result.FullName | Should -Be 'C:\Logs'
                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Logs' -and $ItemType -eq 'Directory'
                }
            }
        }
    }

    Context 'When New-Item fails' {
        It 'Should propagate the underlying error' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock New-Item { throw [System.IO.IOException]::new('Directory already exists as a file') }

                { New-ItemDirectoryWrapper -Path 'C:\Logs' } | Should -Throw
            }
        }
    }
}
