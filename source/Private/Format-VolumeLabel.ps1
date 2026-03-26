function Format-VolumeLabel {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [char]
        $DriveLetter,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FileSystemLabel
    )
    begin {
        Write-ToLog -Message "Setting volume label for drive '$DriveLetter' to '$FileSystemLabel'" -Level INFO
    }
    process {
        try {
            # Inlined NTFS label validation — replaces standalone Assert-NTFSVolumeLabel
            if ($FileSystemLabel.Length -gt 32) {
                throw "NTFS volume label '$FileSystemLabel' exceeds the maximum length of 32 characters."
            }

            if ($FileSystemLabel -match '[\\\/:\*\?"<>\|]') {
                throw "NTFS volume label '$FileSystemLabel' contains invalid characters. Invalid: \ / : * ? "" < > |"
            }

            if ($FileSystemLabel.ToCharArray() | Where-Object { [int]$_ -lt 32 }) {
                throw "NTFS volume label '$FileSystemLabel' contains control characters (ASCII < 32), which are invalid."
            }

            $vol = Get-Volume -DriveLetter $DriveLetter -ErrorAction Stop

            if ($vol.FileSystemLabel -eq $FileSystemLabel) {
                Write-ToLog -Message "Volume '$DriveLetter' already has label '$FileSystemLabel'. No change needed." -Level INFO
                return
            }

            if ($PSCmdlet.ShouldProcess("$DriveLetter`:", "Set volume label to '$FileSystemLabel'")) {
                Write-ToLog -Message "Relabelling volume '$DriveLetter' from '$($vol.FileSystemLabel)' to '$FileSystemLabel'" -Level INFO
                Set-Volume -DriveLetter $DriveLetter -NewFileSystemLabel $FileSystemLabel -ErrorAction Stop
                Write-ToLog -Message "Volume '$DriveLetter' labelled '$FileSystemLabel' successfully." -Level SUCCESS
            }
        }
        catch {
            Write-ToLog -Message "Failed to set volume label for drive '$DriveLetter': $_" -Level ERROR
            throw
        }
    }
}
