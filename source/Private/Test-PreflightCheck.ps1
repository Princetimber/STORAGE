function Test-PreflightCheck {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [System.Security.Principal.WindowsIdentity]
        $Identity
    )

    $earlyExit = $false
    Write-ToLog -Message "Starting preflight check for storage provisioning...." -Level INFO

    $checksPerformed = 0
    $checksPassed = 0
    $checksFailed = 0

    # Platform Validation Check: Windows Server 2016 or later
    if (-not $earlyExit) {
        $checksPerformed++
        try {
            if (-not $IsWindows) {
                Write-ToLog -Message "Platform validation failed: Not running on Windows." -Level ERROR
                $checksFailed++
                $earlyExit = $true
            }
            else {
                $os = Get-Ciminstance -ClassName Win32_OperatingSystem -ErrorAction Stop
                if ($os.ProductType -ne 3) {
                    $bullet = if ($PSStyle) { "$($PSStyle.Foreground.Cyan)*$($PSStyle.Reset)" } else { "*" }
                    $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)Tip:$($PSStyle.Reset)" } else { "i" }

                    $errorMsg = "Platform validation failed: Windows Server required (ProductType 3)."
                    $errorMsg += "`n`nCurrent system:`n  ${bullet} OS: $($os.Caption)`n  ${bullet} ProductType: $($os.ProductType) (1=Workstation, 2=Domain Controller, 3=Server)"
                    $errorMsg += "`n`n${tip} Tip: This module is designed for Windows Server installations only."

                    Write-ToLog -Message "Platform check failed: Windows Server not detected (ProductType: $($os.ProductType))." -Level ERROR
                    throw $errorMsg
                }
                Write-ToLog -Message "Platform validation passed: Running on Windows Server." -Level INFO
                $checksPassed++
            }
        }
        catch {
            Write-ToLog -Message "Platform validation error: $($_.Exception.Message)" -Level ERROR
            $checksFailed++
            $earlyExit = $true
        }
    }

    # Identity and Elevation Check: Ensure running with administrative privileges
    if (-not $earlyExit) {
        $checksPerformed++
        try {
            if (-not $PSBoundParameters.ContainsKey('Identity')) {
                $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                Write-ToLog -Message "Identity parameter not provided. Using current Windows identity: $($Identity.Name)" -Level INFO
            }
            $Principal = [System.Security.Principal.WindowsPrincipal]::new($Identity)
            $IsAdmin = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $IsAdmin) {
                Write-ToLog -Message "Identity check failed: Current user '$($Identity.Name)' does not have administrative privileges." -Level ERROR
                $checksFailed++
                $earlyExit = $true
            }
            else {
                Write-ToLog -Message "Identity check passed: Current user '$($Identity.Name)' has administrative privileges." -Level INFO
                $checksPassed++
            }
        }
        catch {
            Write-ToLog -Message "Identity validation error: $($_.Exception.Message)" -Level ERROR
            $checksFailed++
            $earlyExit = $true
        }
    }

    # Check available disk resources: Ensure at least one physical disk is available for pooling
    if (-not $earlyExit) {
        $checksPerformed++
        try {
            if (-not (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue)) {
                Write-ToLog -Message "Get-PhysicalDisk cmdlet not found. Ensure the required module is installed, and you are running on a supported version of Windows." -Level ERROR
                $checksFailed++
                $earlyExit = $true
            }
            else {
                $physicalDisks = Get-PhysicalDisk -CanPool $true -ErrorAction Stop
                if (-not $physicalDisks -or $physicalDisks.Count -eq 0) {
                    Write-ToLog -Message "Poolable storage check failed: No physical disks detected on the system." -Level ERROR
                    $checksFailed++
                    $earlyExit = $true
                }
                else {
                    $checksPassed++
                }
            }
        }
        catch {
            Write-ToLog -Message "Available disk resources check error: $($_.Exception.Message)" -Level ERROR
            $checksFailed++
            $earlyExit = $true
        }
    }

    $result = @{
        ChecksPerformed = $checksPerformed
        ChecksPassed    = $checksPassed
        ChecksFailed    = $checksFailed
        EarlyExit       = $earlyExit
    }
    Write-ToLog -Message "Preflight check completed. Checks performed: $($result.ChecksPerformed), Passed: $($result.ChecksPassed), Failed: $($result.ChecksFailed)." -Level INFO
    return $result
}
