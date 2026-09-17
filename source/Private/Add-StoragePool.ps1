function Add-StoragePool {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StorageSubSystemFriendlyName,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoragePoolName,

        [Parameter(Position = 2, Mandatory)]
        [ValidateSet('Simple', 'Mirror', 'Parity')]
        [string]
        $ResiliencySettingName,

        [object[]]
        $PhysicalDisks
    )
    begin {
        Write-ToLog -Message "Ensuring storage pool '$StoragePoolName' (Resiliency: $ResiliencySettingName)" -Level INFO

        # Inline disk-count requirement — Simple:1, Mirror:2, Parity:3
        $requiredDiskCount = switch ($ResiliencySettingName) {
            'Simple' { 1 }
            'Mirror' { 2 }
            'Parity' { 3 }
        }
    }
    process {
        try {
            # Idempotency check — return the existing pool if it already exists (filtered server-side)
            $pool = Get-StoragePool -FriendlyName $StoragePoolName -ErrorAction SilentlyContinue |
                Where-Object StorageSubSystemFriendlyName -EQ $StorageSubSystemFriendlyName

            if ($pool) {
                Write-ToLog -Message "Storage pool '$StoragePoolName' already exists. Reusing." -Level WARN

                # Guardrail: existing pool must have enough disks for the requested resiliency
                $poolDisks = Get-PhysicalDisk -StoragePoolFriendlyName $StoragePoolName -ErrorAction SilentlyContinue
                $poolDiskCount = @($poolDisks).Count

                if ($poolDiskCount -lt $requiredDiskCount) {
                    throw "Storage pool '$StoragePoolName' has $poolDiskCount disk(s), but '$ResiliencySettingName' requires at least $requiredDiskCount disk(s)."
                }

                return $pool
            }

            # Resolve physical disks: use caller-supplied list or auto-select from poolable disks
            if (-not $PhysicalDisks) {
                $poolableDisks = Get-PhysicalDisk -CanPool $true -ErrorAction Stop

                if (-not $poolableDisks) {
                    throw 'No poolable disks found.'
                }

                $poolableCount = @($poolableDisks).Count
                if ($poolableCount -lt $requiredDiskCount) {
                    throw "Insufficient poolable disks. Found $poolableCount, but '$ResiliencySettingName' requires at least $requiredDiskCount."
                }

                # SSD-first, then largest, then name alphabetically
                $PhysicalDisks = $poolableDisks |
                    Sort-Object -Property @(
                        @{ Expression = { $_.MediaType -eq 'SSD' }; Descending = $true },
                        @{ Expression = { $_.Size };                Descending = $true },
                        @{ Expression = { $_.FriendlyName };        Ascending  = $true }
                    ) |
                    Select-Object -First $requiredDiskCount

                $selectedInfo = $PhysicalDisks | ForEach-Object {
                    "$($_.FriendlyName) ($($_.MediaType), $([Math]::Round($_.Size / 1GB, 2)) GB)"
                }
                Write-ToLog -Message "Auto-selected $requiredDiskCount of $poolableCount poolable disk(s): $($selectedInfo -join ', ')" -Level INFO
            }
            else {
                $suppliedCount = @($PhysicalDisks).Count
                if ($suppliedCount -lt $requiredDiskCount) {
                    throw "Supplied $suppliedCount disk(s), but '$ResiliencySettingName' requires at least $requiredDiskCount disk(s)."
                }
                Write-Verbose "Using $suppliedCount caller-supplied disk(s)."
            }

            if ($PSCmdlet.ShouldProcess($StoragePoolName, 'Create storage pool')) {
                $newPoolParams = @{
                    FriendlyName                  = $StoragePoolName
                    StorageSubSystemFriendlyName  = $StorageSubSystemFriendlyName
                    PhysicalDisks                 = $PhysicalDisks
                    ErrorAction                   = 'Stop'
                }
                $pool = New-StoragePool @newPoolParams

                # Report capacity breakdown for operational awareness
                $totalCapacity  = ($PhysicalDisks | Measure-Object -Property Size -Sum).Sum
                $diskCount      = @($PhysicalDisks).Count
                $usableCapacity = switch ($ResiliencySettingName) {
                    'Simple' { $totalCapacity }
                    'Mirror' { $totalCapacity / 2 }
                    'Parity' { $totalCapacity * ($diskCount - 1) / $diskCount }
                }

                $totalGB    = [Math]::Round($totalCapacity / 1GB, 2)
                $usableGB   = [Math]::Round($usableCapacity / 1GB, 2)
                $overheadGB = [Math]::Round(($totalCapacity - $usableCapacity) / 1GB, 2)

                Write-ToLog -Message "Storage pool '$StoragePoolName' created successfully." -Level SUCCESS
                Write-ToLog -Message "Capacity — Total: $totalGB GB, Usable: $usableGB GB, Overhead: $overheadGB GB (Resiliency: $ResiliencySettingName)" -Level INFO

                return $pool
            }
        }
        catch {
            Write-ToLog -Message "Failed to add storage pool '$StoragePoolName': $_" -Level ERROR
            throw
        }
    }
}
