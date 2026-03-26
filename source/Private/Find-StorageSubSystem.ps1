function Find-StorageSubSystem {
    # Returns the best matching Storage SubSystem from the provided CIM instances.
    # Prefers a subsystem whose FriendlyName matches "Windows Storage*" when multiple exist.
    # Falls back to the first available subsystem with an ERROR + WARN log if no preferred match found.
    [CmdletBinding()]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param (
        # Accepts any object array so tests can pass PSCustomObject fakes without live CIM infra.
        # Callers from production code always pass real CimInstance objects from Get-StorageSubSystem.
        [object[]]
        $SubSystems = (Get-StorageSubSystem -ErrorAction Stop)
    )

    begin {
        Write-ToLog -Message "Finding Storage SubSystem" -Level INFO

        try {
            if (-not $SubSystems) {
                Write-ToLog -Message "No Storage SubSystem found" -Level WARN
                return
            }

            if ($SubSystems.Count -gt 1) {
                $preferredSubsystem = $SubSystems | Where-Object { $_.FriendlyName -like "Windows Storage*" } | Select-Object -First 1
                if ($preferredSubsystem) {
                    Write-ToLog -Message "Multiple Storage SubSystems found. Using preferred subsystem: $($preferredSubsystem.FriendlyName)" -Level INFO
                    return $preferredSubsystem
                }
                else {
                    # Build a formatted bullet list of available subsystems for the error message.
                    $bullet    = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)•$($PSStyle.Reset)" } else { "•" }
                    $available = $SubSystems | ForEach-Object { "$bullet $($_.FriendlyName) (Model: $($_.Model))" }
                    $errorMsg  = "Multiple Storage SubSystems found, but no preferred Windows Storage SubSystem detected."
                    $errorMsg += "`n`nAvailable Storage SubSystems:`n  $($available -join "`n  ")"
                    $errorMsg += "`n`nPlease specify the desired Storage SubSystem using the -SubSystems parameter or ensure that the Windows Storage SubSystem is properly installed and configured."
                    Write-ToLog -Message $errorMsg -Level ERROR
                    Write-ToLog -Message "Falling back to first available subsystem: $($SubSystems[0].FriendlyName)" -Level WARN
                    return $SubSystems | Select-Object -First 1
                }
            }

            return $SubSystems | Select-Object -First 1
        }
        catch {
            Write-ToLog -Message "Failed to find Storage SubSystem. $($_.Exception.Message)" -Level ERROR
            throw
        }
    }

}
