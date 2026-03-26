function Remove-Storage {
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal helper — ShouldProcess is owned by the calling Invoke-Storage function.')]
    param (
        [Parameter(Mandatory)]
        [string]
        $StoragePoolName,

        [Parameter(Mandatory)]
        [string]
        $VirtualHardDiskName,

        [Parameter(Mandatory)]
        [string]
        $Workload
    )

    Write-ToLog -Message "Removing storage resources for '$Workload'." -Level WARN

    $vhd = Get-VirtualDisk -FriendlyName $VirtualHardDiskName -ErrorAction SilentlyContinue
    if ($vhd) {
        $disk = $vhd | Get-Disk -ErrorAction SilentlyContinue

        if ($disk) {
            $partitions = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue
            if ($partitions) {
                $partitions | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue
            }

            if (-not $disk.IsOffline) {
                Set-Disk -Number $disk.Number -IsOffline $true -ErrorAction SilentlyContinue
            }
        }

        Remove-VirtualDisk -FriendlyName $VirtualHardDiskName -Confirm:$false -ErrorAction Stop
        Write-ToLog -Message "Virtual disk '$VirtualHardDiskName' removed." -Level INFO
    }

    $workloadProfile = if ($script:StorageWorkloadProfiles) {
        $script:StorageWorkloadProfiles[$Workload]
    }
    else {
        $null
    }

    if ($workloadProfile -and $workloadProfile.RootFiles) {
        foreach ($file in $workloadProfile.RootFiles) {
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }

    if ($workloadProfile -and $workloadProfile.DriveFiles -and $disk -and $partitions) {
        foreach ($part in @($partitions)) {
            if ($part.DriveLetter) {
                foreach ($file in $workloadProfile.DriveFiles) {
                    Remove-Item -Path "$($part.DriveLetter):\$file" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    $pool = Get-StoragePool -FriendlyName $StoragePoolName -ErrorAction SilentlyContinue
    if ($pool) {
        $remainingVDs = $pool | Get-VirtualDisk -ErrorAction SilentlyContinue
        if (-not $remainingVDs) {
            Start-Sleep -Seconds 2
            Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false -ErrorAction Stop
            Write-ToLog -Message "Storage pool '$StoragePoolName' removed." -Level INFO
        }
    }
}
