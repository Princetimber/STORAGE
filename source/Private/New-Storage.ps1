$script:StorageWorkloadProfiles = @{
    SYSVOL             = @{
        Directories = @(
            @{ Path = 'SYSVOL'; Hidden = $true }
        )
    }
    NTDS               = @{
        Directories = @(
            @{ Path = 'NTDS'; Hidden = $true },
            @{ Path = 'NTDS\LOGS'; Hidden = $true }
        )
    }
    ConfigMgrInstall   = @{
        RootFiles = @('C:\no_sms_on_drive.sms')
    }
    ApplicationSources = @{
        DriveFiles = @('no_sms_on_drive.sms')
    }
    ContentLibrary     = @{
        DriveFiles = @('no_sms_on_drive.sms')
    }
    SQL_MDF            = @{
        Directories = @(
            @{ Path = 'DataBase'; Hidden = $false }
        )
        DriveFiles  = @('no_sms_on_drive.sms')
    }
    SQL_LDF            = @{
        Directories = @(
            @{ Path = 'DataBase'; Hidden = $false }
        )
        DriveFiles  = @('no_sms_on_drive.sms')
    }
    TempDB             = @{
        Directories = @(
            @{ Path = 'DataBase'; Hidden = $false }
        )
        DriveFiles  = @('no_sms_on_drive.sms')
    }
    WSUSDB             = @{
        Directories = @(
            @{ Path = 'DataBase'; Hidden = $false }
        )
        DriveFiles  = @('no_sms_on_drive.sms')
    }
    Generic            = @{
        # Intentionally empty: no directories, no SMS files
    }
}

function New-Storage {
    [CmdletBinding()]
    [OutputType([char])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal helper — ShouldProcess is owned by the calling Invoke-Storage function.')]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoragePoolName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $VirtualHardDiskName,

        [Parameter(Mandatory)]
        [ValidateSet(
            'SYSVOL', 'NTDS', 'ConfigMgrInstall', 'SQL_MDF', 'SQL_LDF',
            'TempDB', 'WSUSDB', 'ApplicationSources', 'ContentLibrary', 'Generic'
        )]
        [string]
        $Workload,

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
        $NoPostCreateArtifacts
    )

    $resolvedLabel = if ($PSBoundParameters.ContainsKey('FileSystemLabel')) {
        $FileSystemLabel
    }
    else {
        $Workload
    }

    if ($PSBoundParameters.ContainsKey('FileSystemLabel') -and $resolvedLabel -ne $Workload) {
        Write-ToLog -Message (
            "Custom FileSystemLabel '$resolvedLabel' applied for workload '$Workload'. " +
            'Behaviour is determined by Workload.'
        ) -Level WARN
    }

    $workloadProfile = $script:StorageWorkloadProfiles[$Workload]
    if (-not $workloadProfile -and -not $script:StorageWorkloadProfiles.ContainsKey($Workload)) {
        throw "No workload profile found for '$Workload'."
    }

    if ($Remove.IsPresent) {
        Remove-Storage `
            -StoragePoolName $StoragePoolName `
            -VirtualHardDiskName $VirtualHardDiskName `
            -Workload $Workload

        Write-ToLog -Message "Storage resources for '$Workload' removed successfully." -Level INFO
        return
    }

    Write-ToLog -Message "Starting storage provisioning for '$Workload'." -Level INFO

    $driveLetter = $null

    try {
        $vhdParams = @{
            StoragePoolName       = $StoragePoolName
            VirtualDiskName       = $VirtualHardDiskName
            ResiliencySettingName = $ResiliencySettingName
            ProvisioningType      = $ProvisioningType
        }

        if ($PSBoundParameters.ContainsKey('SizeInGB')) {
            $vhdParams.Size = $SizeInGB * 1GB
        }
        elseif ($UseMaximumSize.IsPresent) {
            $vhdParams.UseMaximumSize = $true
        }
        else {
            throw 'Either sizeInGB or useMaximumSize must be specified.'
        }

        $subsystems = Get-StorageSubSystem -ErrorAction Stop
        $subsystem = Find-StorageSubSystem -SubSystems $subsystems
        $subSystemName = $subsystem.FriendlyName

        Write-ToLog -Message "Creating storage pool '$StoragePoolName'." -Level INFO
        Add-StoragePool `
            -StorageSubSystemFriendlyName $subSystemName `
            -StoragePoolName $StoragePoolName `
            -ResiliencySettingName $ResiliencySettingName

        Write-ToLog -Message "Creating virtual disk '$VirtualHardDiskName'." -Level INFO
        $vDisk = Add-VirtualDisk @vhdParams

        Write-ToLog -Message "Initialising disk and assigning drive letter." -Level INFO
        $driveLetter = Initialize-StorageDisk -VirtualHardDisk $vDisk

        Write-ToLog -Message "Formatting volume label on drive $driveLetter." -Level INFO
        Format-VolumeLabel -DriveLetter $driveLetter -FileSystemLabel $resolvedLabel

        return $driveLetter
    }
    catch {
        Write-ToLog -Message "Error during storage provisioning for '$Workload': $_" -Level ERROR
        throw
    }
    finally {
        if (-not $Remove.IsPresent -and $driveLetter) {
            if ($NoPostCreateArtifacts.IsPresent) {
                Write-ToLog -Message 'Post-create artifacts suppressed via -NoPostCreateArtifacts.' -Level WARN
            }
            else {
                if ($workloadProfile.Directories) {
                    foreach ($dir in $workloadProfile.Directories) {
                        New-ItemIfAbsent -Path "$driveLetter`:\$($dir.Path)" -Type Directory -Hidden:([bool]$dir.Hidden)
                    }
                }

                if ($workloadProfile.DriveFiles) {
                    foreach ($file in $workloadProfile.DriveFiles) {
                        New-ItemIfAbsent -Path "$driveLetter`:\$file" -Type File
                    }
                }

                if ($workloadProfile.RootFiles) {
                    foreach ($file in $workloadProfile.RootFiles) {
                        New-ItemIfAbsent -Path $file -Type File
                    }
                }

                Write-ToLog -Message "Storage provisioning for '$Workload' completed successfully." -Level SUCCESS
            }
        }
    }
}
