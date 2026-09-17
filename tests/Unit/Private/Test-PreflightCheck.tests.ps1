#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'Invoke-Storage'

    Import-Module -Name $script:dscModuleName

    $script:isElevatedAdmin = ([Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Test-PreflightCheck' -Tag 'Unit' {
    <#
        $IsWindows is a read-only automatic variable and cannot be overridden
        from a test, so the "not running on Windows" branch is exercised via
        code review rather than a unit test here; the "not Windows Server"
        and "no poolable disks" cases below cover the same early-exit pattern.
    #>
    Context 'When running on Windows but not Windows Server' {
        It 'Should fail fast and still return a result hashtable with EarlyExit true' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Ciminstance { [PSCustomObject]@{ ProductType = 1; Caption = 'Windows 11 Pro' } }

                $result = Test-PreflightCheck

                $result | Should -Not -BeNullOrEmpty
                $result.EarlyExit | Should -BeTrue
                $result.ChecksFailed | Should -Be 1
            }
        }
    }

    Context 'When no poolable physical disks are found' -Skip:(-not $script:isElevatedAdmin) {
        It 'Should fail fast and still return a result hashtable with EarlyExit true' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Ciminstance { [PSCustomObject]@{ ProductType = 3; Caption = 'Windows Server' } }
                Mock Get-PhysicalDisk { @() }

                $result = Test-PreflightCheck

                $result | Should -Not -BeNullOrEmpty
                $result.EarlyExit | Should -BeTrue
                $result.ChecksFailed | Should -Be 1
                $result.ChecksPassed | Should -Be 2
            }
        }
    }

    Context 'When all checks pass' -Skip:(-not $script:isElevatedAdmin) {
        It 'Should return a result hashtable with EarlyExit false and all checks passed' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-ToLog
                Mock Get-Ciminstance { [PSCustomObject]@{ ProductType = 3; Caption = 'Windows Server' } }
                Mock Get-PhysicalDisk { @([PSCustomObject]@{ CanPool = $true }) }

                $result = Test-PreflightCheck

                $result.EarlyExit | Should -BeFalse
                $result.ChecksPerformed | Should -Be 3
                $result.ChecksPassed | Should -Be 3
                $result.ChecksFailed | Should -Be 0
            }
        }
    }
}
