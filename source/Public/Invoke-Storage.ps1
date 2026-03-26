function Invoke-Storage {
    <#
    .SYNOPSIS
        Creates or removes Storage Spaces resources (pool/virtual disk/volume).

    .DESCRIPTION
        Public entry point that wraps New-Storage with preflight validation, WhatIf/Confirm
        support, and centralised logging. Runs environment checks (Windows Server, admin
        privileges, poolable disks) before any storage operation.

        Creates resources in order: storage pool → virtual disk → volume initialisation →
        NTFS label → workload-specific artifacts. The -remove switch reverses this process.

    .PARAMETER StoragePoolName
        Friendly name for the storage pool to create or remove.

    .PARAMETER VirtualHardDiskName
        Friendly name for the virtual disk to create or remove.

    .PARAMETER Workload
        The workload profile that determines post-create artifacts.
        Valid values: SYSVOL, NTDS, ConfigMgrInstall, SQL_MDF, SQL_LDF,
        TempDB, WSUSDB, ApplicationSources, ContentLibrary, Generic.

    .PARAMETER FileSystemLabel
        Optional volume label override. Defaults to the workload name when not specified.

    .PARAMETER ResiliencySettingName
        Resiliency type: Simple (1 disk), Mirror (2 disks), or Parity (3 disks).
        Defaults to Simple.

    .PARAMETER ProvisioningType
        Provisioning type: Fixed or Thin. Defaults to Thin.

    .PARAMETER SizeInGB
        Size of the virtual disk in gigabytes. Required unless -UseMaximumSize is specified.

    .PARAMETER UseMaximumSize
        Use the maximum available size for the virtual disk.

    .PARAMETER Remove
        Remove storage resources instead of creating them.

    .PARAMETER NoPostCreateArtifacts
        Suppress creation of post-create directories and marker files.

    .PARAMETER PassThru
        Return a rich object with DriveLetter, StoragePool, VirtualDisk, Volume, and Capacity
        properties instead of just the drive letter.

    .PARAMETER Force
        Suppress all confirmation prompts. Use with caution.

    .OUTPUTS
        System.Char
        Drive letter of the created volume. Returns $null when removing resources.

        PSCustomObject (when -passThru is specified)
        Object with properties: DriveLetter, StoragePool, VirtualDisk, Volume, Capacity.

    .EXAMPLE
        Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload NTDS -SizeInGB 50

        Creates a 50 GB storage stack for NTDS with Simple resiliency.

    .EXAMPLE
        Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload SQL_MDF -UseMaximumSize -ResiliencySettingName Mirror

        Creates a mirrored storage stack using maximum available space for SQL MDF files.

    .EXAMPLE
        Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload NTDS -Remove

        Removes all storage resources associated with the NTDS workload.

    .EXAMPLE
        Invoke-Storage -StoragePoolName 'TestPool' -VirtualHardDiskName 'TestVDisk' -Workload Generic -SizeInGB 50 -WhatIf

        Preview mode: shows what would be created without making changes.

    .EXAMPLE
        $result = Invoke-Storage -StoragePoolName 'Pool1' -VirtualHardDiskName 'VDisk1' -Workload SQL_MDF -SizeInGB 500 -PassThru
        Write-Host "Created pool: $($result.StoragePool.FriendlyName)"

        Use -PassThru to capture full resource details for further operations.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([char])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoragePoolName,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $VirtualHardDiskName,

        [Parameter(Mandatory, Position = 2)]
        [ValidateSet(
            'SYSVOL', 'NTDS', 'ConfigMgrInstall', 'SQL_MDF', 'SQL_LDF',
            'TempDB', 'WSUSDB', 'ApplicationSources', 'ContentLibrary', 'Generic'
        )]
        [string]
        $Workload,

        [Parameter(Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FileSystemLabel,

        [ValidateSet('Simple', 'Mirror', 'Parity')]
        [string]
        $ResiliencySettingName = 'Simple',

        [ValidateSet('Fixed', 'Thin')]
        [string]
        $ProvisioningType = 'Thin',

        [ValidateRange(1, [Int64]::MaxValue)]
        [Nullable[Int64]]
        $SizeInGB,

        [switch]
        $UseMaximumSize,

        [switch]
        $Remove,

        [switch]
        $NoPostCreateArtifacts,

        [switch]
        $PassThru,

        [switch]
        $Force
    )

    $succeeded = $false

    try {
        if ($Force.IsPresent) {
            $ConfirmPreference = 'None'
        }

        Write-ToLog -Message 'Running preflight checks.' -Level INFO
        $preflight = Test-PreflightCheck
        if ($preflight.EarlyExit) {
            throw 'Preflight checks failed. See log for details.'
        }

        $action = if ($Remove.IsPresent) { 'Remove' } else { 'Create' }

        if (-not $Remove.IsPresent -and
            -not $PSBoundParameters.ContainsKey('SizeInGB') -and
            -not $UseMaximumSize.IsPresent) {
            throw 'Either -sizeInGB or -useMaximumSize must be specified when creating storage resources.'
        }

        Write-ToLog -Message "Invoke-Storage starting. Action='$action', Workload='$Workload', Pool='$StoragePoolName'." -Level INFO

        $target = "Workload='$Workload', Pool='$StoragePoolName', VHD='$VirtualHardDiskName'"
        $operation = if ($Remove.IsPresent) { 'Remove storage resources' } else { 'Create storage resources' }

        if (-not $PSCmdlet.ShouldProcess($target, $operation)) {
            Write-ToLog -Message "Operation cancelled by ShouldProcess. $operation for $target." -Level WARN
            return
        }

        $params = @{
            StoragePoolName       = $StoragePoolName
            VirtualHardDiskName   = $VirtualHardDiskName
            Workload              = $Workload
            ResiliencySettingName = $ResiliencySettingName
            ProvisioningType      = $ProvisioningType
        }

        if ($PSBoundParameters.ContainsKey('FileSystemLabel')) {
            $params.FileSystemLabel = $FileSystemLabel
        }

        if ($PSBoundParameters.ContainsKey('SizeInGB')) {
            $params.SizeInGB = $SizeInGB
        }
        elseif ($UseMaximumSize.IsPresent) {
            $params.UseMaximumSize = $true
        }

        if ($NoPostCreateArtifacts.IsPresent) {
            $params.NoPostCreateArtifacts = $true
        }

        if ($Remove.IsPresent) {
            $params.Remove = $true
            Write-ToLog -Message "Removing storage resources for $target." -Level INFO
            New-Storage @params
            Write-ToLog -Message "Removal completed for $target." -Level INFO
            $succeeded = $true
            return
        }

        Write-ToLog -Message "Creating storage resources for $target." -Level INFO
        $driveLetter = New-Storage @params
        Write-ToLog -Message "Creation completed for $target. DriveLetter='$driveLetter'." -Level INFO
        $succeeded = $true

        if ($PassThru.IsPresent) {
            $pool = Get-StoragePool -FriendlyName $StoragePoolName -ErrorAction SilentlyContinue
            $vdisk = Get-VirtualDisk -FriendlyName $VirtualHardDiskName -ErrorAction SilentlyContinue
            $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue

            return [PSCustomObject]@{
                PSTypeName  = 'Invoke.Storage.Result'
                DriveLetter = $driveLetter
                StoragePool = $pool
                VirtualDisk = $vdisk
                Volume      = $volume
                Capacity    = if ($pool) {
                    [PSCustomObject]@{
                        TotalGB  = [Math]::Round($pool.Size / 1GB, 2)
                        UsableGB = [Math]::Round(($pool.Size - $pool.AllocatedSize) / 1GB, 2)
                    }
                }
                else {
                    $null
                }
            }
        }

        return $driveLetter
    }
    catch {
        Write-ToLog -Message "An error occurred during Invoke-Storage: $_" -Level ERROR
        throw
    }
    finally {
        if ($succeeded) {
            Write-ToLog -Message "Invoke-Storage completed successfully for Pool='$StoragePoolName', VHD='$VirtualHardDiskName'." -Level INFO
        }
    }
}
