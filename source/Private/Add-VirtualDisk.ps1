function Add-VirtualDisk {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StoragePoolName,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $VirtualDiskName,

        [Parameter(Position = 2)]
        [ValidateSet('Simple', 'Mirror', 'Parity')]
        [string]
        $ResiliencySettingName = 'Simple',

        [Parameter()]
        [ValidateSet('Fixed', 'Thin')]
        [string]
        $ProvisioningType = 'Thin',

        [Parameter()]
        [ValidateRange(1, [Int64]::MaxValue)]
        [Nullable[Int64]]
        $Size,

        [Parameter()]
        [switch]
        $UseMaximumSize
    )
    begin {
        Write-ToLog -Message "Ensuring virtual disk '$VirtualDiskName' on pool '$StoragePoolName'" -Level INFO
    }
    process {
        try {
            # Idempotency check — return the existing virtual disk if it already exists
            $existing = Get-VirtualDisk -FriendlyName $VirtualDiskName -ErrorAction SilentlyContinue
            if ($existing) {
                Write-ToLog -Message "Virtual disk '$VirtualDiskName' already exists. Reusing." -Level WARN
                return $existing
            }

            # Simple resiliency + UseMaximumSize requires Fixed provisioning (Windows Storage constraint)
            if ($ResiliencySettingName -eq 'Simple' -and $UseMaximumSize.IsPresent) {
                Write-ToLog -Message "Forcing ProvisioningType = Fixed (Simple + UseMaximumSize)" -Level WARN
                $ProvisioningType = 'Fixed'
            }

            $params = @{
                FriendlyName            = $VirtualDiskName
                StoragePoolFriendlyName = $StoragePoolName
                ResiliencySettingName   = $ResiliencySettingName
                ProvisioningType        = $ProvisioningType
            }

            # Simple resiliency must use a single column to avoid striping
            if ($ResiliencySettingName -eq 'Simple') {
                $params.NumberOfColumns = 1
            }

            # Size and UseMaximumSize are mutually exclusive; one must be provided
            if ($PSBoundParameters.ContainsKey('Size') -and $Size -gt 0) {
                $params.Size = $Size
            }
            elseif ($UseMaximumSize.IsPresent) {
                $params.UseMaximumSize = $true
            }
            else {
                throw "Either -Size or -UseMaximumSize must be specified."
            }

            if ($PSCmdlet.ShouldProcess($VirtualDiskName, 'Create virtual disk')) {
                $vDisk = New-VirtualDisk @params -ErrorAction Stop
                Write-ToLog -Message "Virtual disk '$VirtualDiskName' created successfully." -Level SUCCESS
                return $vDisk
            }
        }
        catch {
            Write-ToLog -Message "Failed to create virtual disk '$VirtualDiskName': $_" -Level ERROR
            throw
        }
    }
}
