#Requires -Version 7.0

# Clears the active log file. ConfirmImpact=High — always prompts unless -Force or -Confirm:$false.
# -Archive creates a timestamped .bak copy before clearing.
function Clear-LogFile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter()]
        [switch]$Archive,

        [Parameter()]
        [switch]$Force
    )

    if ($Force) { $ConfirmPreference = 'None' }

    if (-not (Test-PathWrapper -LiteralPath $script:LogFile)) {
        Write-Verbose "Log file does not exist: $script:LogFile"
        return
    }

    if ($PSCmdlet.ShouldProcess($script:LogFile, "Clear log file")) {
        if ($Archive) {
            $archiveName = "$script:LogFile.$([System.DateTimeOffset]::UtcNow.ToString($script:LogTimestampFormat)).bak"
            $archiveDir = [System.IO.Path]::GetDirectoryName($archiveName)
            if ($archiveDir -and -not (Test-PathWrapper -LiteralPath $archiveDir)) {
                $tip = if ($PSStyle) { "$($PSStyle.Foreground.Yellow)ℹ$($PSStyle.Reset)" } else { "ℹ" }
                throw "Archive destination directory '$archiveDir' does not exist.`n`n${tip} Tip: Verify the log file path is valid and the directory is accessible."
            }
            Copy-ItemWrapper -LiteralPath $script:LogFile -Destination $archiveName
            Write-Verbose "Log archived to: $archiveName"
        }

        Clear-ContentWrapper -LiteralPath $script:LogFile
        Write-ToLog -Message "===== Log file cleared =====" -Level INFO
    }
}
