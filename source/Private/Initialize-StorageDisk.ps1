function Initialize-StorageDisk {
    [CmdletBinding()]
    [OutputType([char])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]
        $VirtualHardDisk
    )

    $disk = $VirtualHardDisk | Get-Disk -ErrorAction Stop

    if ($disk.Offline) {
        Write-ToLog -Message "Bringing disk $($disk.Number) online." -Level INFO
        Set-Disk -Number $disk.Number -IsOffline $false -ErrorAction Stop
    }

    if ($disk.IsReadOnly) {
        Write-ToLog -Message "Clearing read-only flag on disk $($disk.Number)." -Level INFO
        Set-Disk -Number $disk.Number -IsReadOnly $false -ErrorAction Stop
    }

    if ($disk.PartitionStyle -eq 'RAW') {
        Write-ToLog -Message "Initialising disk $($disk.Number) as GPT." -Level INFO
        Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop
    }

    $partition = Get-Partition -DiskNumber $disk.Number |
        Where-Object DriveLetter |
        Select-Object -First 1

    if (-not $partition) {
        Write-ToLog -Message "Creating partition on disk $($disk.Number)." -Level INFO
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
    }

    return $partition.DriveLetter
}
