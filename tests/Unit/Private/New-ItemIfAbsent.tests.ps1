#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    if (-not (Get-Module -Name $script:dscModuleName)) {
        $outputManifest = Join-Path $PSScriptRoot '../../../output/module/Invoke-Storage' |
            Get-ChildItem -Filter 'Invoke-Storage.psd1' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -Last 1

        if ($outputManifest) {
            Import-Module -Name $outputManifest.FullName -Force
        }
        else {
            Import-Module -Name $script:dscModuleName
        }
    }
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'New-ItemIfAbsent' -Tag 'Unit' {

    Context 'When the path already exists' {
        It 'Should not call New-Item for a directory' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $true }
                Mock New-Item

                New-ItemIfAbsent -Path 'D:\NTDS' -Type 'Directory'

                Should -Invoke New-Item -Times 0
            }
        }

        It 'Should not call New-Item for a file' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $true }
                Mock New-Item

                New-ItemIfAbsent -Path 'D:\no_sms_on_drive.sms' -Type 'File'

                Should -Invoke New-Item -Times 0
            }
        }
    }

    Context 'When the directory does not exist' {
        It 'Should create the directory' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $false }
                Mock New-Item { return [PSCustomObject]@{ FullName = 'D:\NTDS' } }

                New-ItemIfAbsent -Path 'D:\NTDS' -Type 'Directory'

                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq 'D:\NTDS'
                }
            }
        }

        It 'Should default to Directory type when -Type is omitted' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $false }
                Mock New-Item { return [PSCustomObject]@{ FullName = 'D:\NTDS' } }

                New-ItemIfAbsent -Path 'D:\NTDS'

                Should -Invoke New-Item -Times 1 -ParameterFilter { $ItemType -eq 'Directory' }
            }
        }
    }

    Context 'When the file does not exist' {
        It 'Should create the file' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $false }
                Mock New-Item { return [PSCustomObject]@{ FullName = 'D:\no_sms_on_drive.sms' } }

                New-ItemIfAbsent -Path 'D:\no_sms_on_drive.sms' -Type 'File'

                Should -Invoke New-Item -Times 1 -ParameterFilter {
                    $ItemType -eq 'File' -and $Path -eq 'D:\no_sms_on_drive.sms'
                }
            }
        }
    }

    Context 'When -hidden is specified for a directory' {
        It 'Should set the Hidden attribute after creation' {
            InModuleScope -ModuleName $script:dscModuleName {
                $fakeAttributes = [System.IO.FileAttributes]::Normal
                $fakeItem = [PSCustomObject]@{ Attributes = $fakeAttributes }
                # Allow attribute assignment via a setter
                $fakeItem | Add-Member -MemberType ScriptProperty -Name Attributes -Force `
                    -Value { $script:capturedAttribs } `
                    -SecondValue { param($v) $script:capturedAttribs = $v }
                $script:capturedAttribs = [System.IO.FileAttributes]::Normal

                Mock Test-Path { return $false }
                Mock New-Item { return $fakeItem }
                Mock Get-Item { return $fakeItem }

                New-ItemIfAbsent -Path 'D:\SYSVOL' -Type 'Directory' -hidden

                Should -Invoke Get-Item -Times 1
                ($script:capturedAttribs -band [System.IO.FileAttributes]::Hidden) | Should -Not -Be 0
            }
        }
    }

    Context 'When -hidden is specified for a file' {
        It 'Should create the file without setting Hidden attribute' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Test-Path { return $false }
                Mock New-Item { return [PSCustomObject]@{ FullName = 'D:\marker.sms' } }
                Mock Get-Item

                New-ItemIfAbsent -Path 'D:\marker.sms' -Type 'File' -hidden

                # Hidden only applies to directories — Get-Item should not be called for files
                Should -Invoke Get-Item -Times 0
            }
        }
    }

}
